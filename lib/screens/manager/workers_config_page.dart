import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';

class WorkersConfigPage extends StatefulWidget {
  const WorkersConfigPage({super.key});

  @override
  State<WorkersConfigPage> createState() => _WorkersConfigPageState();
}

class _WorkersConfigPageState extends State<WorkersConfigPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Form controllers for Create New Worker tab
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _joiningDateController = TextEditingController();
  final TextEditingController _salaryController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String? _selectedDesignation;
  bool _isSalaryEditable = false;
  String _searchQuery = '';
  String _selectedFilterDesignation = 'All';

  // Editing controllers for Workers List tab
  final Map<String, TextEditingController> _editingControllers = {};
  final Map<String, bool> _isEditing = {};

  List<Map<String, dynamic>> _designations = [];
  bool _isSubmitting = false;

  Color get primaryColor => Theme.of(context).primaryColor;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDesignations();
    _joiningDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _joiningDateController.dispose();
    _salaryController.dispose();
    _searchController.dispose();
    for (var controller in _editingControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDesignations() async {
    try {
      final querySnapshot = await FirestoreService.getCollection('labours').get();
      if (!mounted) return;
      setState(() {
        _designations = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'designation': data['designation'] ?? '',
            'salary': data['salary']?.toString() ?? '',
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('Error loading designations: $e');
    }
  }

  Future<String> _getNextWorkerId() async {
    try {
      final querySnapshot = await FirestoreService.getCollection('workersConfig')
          .orderBy('workerId', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return 'WC001';
      }

      final lastWorker = querySnapshot.docs.first;
      final lastWorkerId = lastWorker['workerId'] as String? ?? 'WC000';

      final numberStr = lastWorkerId.replaceAll(RegExp(r'[^0-9]'), '');
      final nextNumber = (int.tryParse(numberStr) ?? 0) + 1;

      return 'WC${nextNumber.toString().padLeft(3, '0')}';
    } catch (e) {
      debugPrint('Error generating worker ID: $e');
      return 'WC001';
    }
  }

  Future<void> _createWorker() async {
    if (_nameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _selectedDesignation == null ||
        _salaryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_phoneController.text.trim().length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number must be exactly 10 digits'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final workerId = await _getNextWorkerId();

      await FirestoreService.getCollection('workersConfig').doc(workerId).set({
        'workerId': workerId,
        'name': _nameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'designation': _selectedDesignation,
        'salary': _salaryController.text.trim(),
        'joiningDate': _joiningDateController.text.trim(),
        'address': _addressController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      _nameController.clear();
      _phoneController.clear();
      _addressController.clear();
      _salaryController.clear();
      setState(() {
        _selectedDesignation = null;
        _isSalaryEditable = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Worker registered successfully with ID: $workerId'),
          backgroundColor: Colors.green,
        ),
      );

      _tabController.animateTo(1);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error registering worker: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _startEditing(String docId, Map<String, dynamic> data) {
    setState(() {
      _isEditing[docId] = true;
      _editingControllers['${docId}_name'] = TextEditingController(text: data['name'] ?? '');
      _editingControllers['${docId}_phone'] = TextEditingController(text: data['phoneNumber'] ?? '');
      _editingControllers['${docId}_salary'] = TextEditingController(text: data['salary']?.toString() ?? '');
      _editingControllers['${docId}_joiningDate'] = TextEditingController(text: data['joiningDate'] ?? '');
      _editingControllers['${docId}_address'] = TextEditingController(text: data['address'] ?? '');
    });
  }

  void _cancelEditing(String docId) {
    setState(() {
      _isEditing[docId] = false;
      _editingControllers['${docId}_name']?.dispose();
      _editingControllers['${docId}_phone']?.dispose();
      _editingControllers['${docId}_salary']?.dispose();
      _editingControllers['${docId}_joiningDate']?.dispose();
      _editingControllers['${docId}_address']?.dispose();

      _editingControllers.remove('${docId}_name');
      _editingControllers.remove('${docId}_phone');
      _editingControllers.remove('${docId}_salary');
      _editingControllers.remove('${docId}_joiningDate');
      _editingControllers.remove('${docId}_address');
    });
  }

  Future<void> _saveEditing(String docId) async {
    final phone = _editingControllers['${docId}_phone']?.text.trim() ?? '';
    if (phone.isNotEmpty && phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number must be exactly 10 digits'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      await FirestoreService.getCollection('workersConfig').doc(docId).update({
        'name': _editingControllers['${docId}_name']?.text.trim() ?? '',
        'phoneNumber': phone,
        'salary': _editingControllers['${docId}_salary']?.text.trim() ?? '',
        'joiningDate': _editingControllers['${docId}_joiningDate']?.text.trim() ?? '',
        'address': _editingControllers['${docId}_address']?.text.trim() ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _cancelEditing(docId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Worker profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating worker: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _deleteWorker(String docId) async {
    try {
      await FirestoreService.getCollection('workersConfig').doc(docId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Worker registration deleted'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting worker: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _selectDate(BuildContext context, String docId) async {
    final controller = _editingControllers['${docId}_joiningDate'];
    DateTime initialDate = DateTime.now();
    if (controller != null && controller.text.isNotEmpty) {
      try {
        initialDate = DateTime.parse(controller.text);
      } catch (_) {}
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && controller != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
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
          'Workers Configuration',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
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
                      onTap: () => _tabController.animateTo(0),
                      child: AnimatedBuilder(
                        animation: _tabController,
                        builder: (context, _) {
                          final isSelected = _tabController.index == 0;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? primaryColor : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'REGISTER WORKER',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: isSelected ? Colors.white : const Color(0xFF0A183D),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _tabController.animateTo(1),
                      child: AnimatedBuilder(
                        animation: _tabController,
                        builder: (context, _) {
                          final isSelected = _tabController.index == 1;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? primaryColor : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'WORKERS DIRECTORY',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: isSelected ? Colors.white : const Color(0xFF0A183D),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Metrics Strip
            _buildSummaryMetricsStrip(primaryColor),

            // Tab View
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 650),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCreateWorkerTab(primaryColor),
                      _buildWorkersListTab(primaryColor),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetricsStrip(Color primaryColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.getCollection('workersConfig').snapshots(),
      builder: (context, snapshot) {
        final totalWorkers = snapshot.data?.docs.length ?? 0;
        final designationsSet = <String>{};
        double totalSalary = 0;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final des = data['designation']?.toString() ?? '';
            if (des.isNotEmpty) designationsSet.add(des);

            final sal = double.tryParse(data['salary']?.toString() ?? '0') ?? 0;
            totalSalary += sal;
          }
        }

        final avgSalary = totalWorkers > 0 ? (totalSalary / totalWorkers).round() : 0;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricItem(
                'Total Workers',
                '$totalWorkers',
                Icons.people_alt_rounded,
                primaryColor,
              ),
              Container(
                width: 1,
                height: 24,
                color: const Color(0xFFCBD5E1),
              ),
              _buildMetricItem(
                'Roles',
                '${designationsSet.length}',
                Icons.work_history_rounded,
                const Color(0xFF3B82F6),
              ),
              Container(
                width: 1,
                height: 24,
                color: const Color(0xFFCBD5E1),
              ),
              _buildMetricItem(
                'Avg Daily Wage',
                '₹$avgSalary',
                Icons.payments_rounded,
                const Color(0xFF16A34A),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricItem(
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A183D),
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCreateWorkerTab(Color primaryColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: 'Personal Details',
            icon: Icons.person_pin_rounded,
            primaryColor: primaryColor,
            children: [
              _buildCustomTextField(
                controller: _nameController,
                label: 'Full Name *',
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 14),
              _buildCustomTextField(
                controller: _phoneController,
                label: 'Phone Number (10 Digits) *',
                icon: Icons.phone_android_rounded,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
              ),
            ],
          ),

          _buildSectionCard(
            title: 'Role & Daily Wages',
            icon: Icons.work_history_rounded,
            primaryColor: primaryColor,
            children: [
              _buildDesignationDropdown(primaryColor),
              const SizedBox(height: 14),
              _buildSalaryField(primaryColor),
              const SizedBox(height: 14),
              _buildCustomTextField(
                controller: _joiningDateController,
                label: 'Joining Date',
                icon: Icons.calendar_month_rounded,
                readOnly: true,
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      _joiningDateController.text = DateFormat(
                        'yyyy-MM-dd',
                      ).format(picked);
                    });
                  }
                },
              ),
            ],
          ),

          _buildSectionCard(
            title: 'Address & Location',
            icon: Icons.location_on_rounded,
            primaryColor: primaryColor,
            children: [
              _buildCustomTextField(
                controller: _addressController,
                label: 'Permanent / Local Address',
                icon: Icons.home_work_outlined,
                maxLines: 3,
              ),
            ],
          ),

          const SizedBox(height: 8),
          _isSubmitting
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _createWorker,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'REGISTER NEW WORKER',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color primaryColor,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: primaryColor),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0A183D),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    bool readOnly = false,
    VoidCallback? onTap,
    String? prefixText,
    Widget? suffixIcon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: readOnly ? const Color(0xFFF1F5F9) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            readOnly: readOnly,
            onTap: onTap,
            maxLines: maxLines,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0A183D),
            ),
            decoration: InputDecoration(
              hintText: 'Enter ${label.replaceAll('*', '').trim()}',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Icon(icon, color: primaryColor, size: 20),
              prefixText: prefixText,
              prefixStyle: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0A183D),
              ),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesignationDropdown(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Designation *',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: _selectedDesignation,
            isExpanded: true,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(14),
            style: const TextStyle(
              color: Color(0xFF0A183D),
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              prefixIcon: Icon(
                Icons.construction_rounded,
                color: primaryColor,
                size: 20,
              ),
              hintText: 'Choose designation (Mason, Helper, etc.)',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
              ),
            ),
            items: _designations.map<DropdownMenuItem<String>>((designation) {
              final designationValue = designation['designation']?.toString() ?? '';
              final salaryValue = designation['salary']?.toString() ?? '';
              return DropdownMenuItem<String>(
                value: designationValue.isEmpty ? null : designationValue,
                onTap: () {
                  setState(() {
                    _salaryController.text = salaryValue;
                    _isSalaryEditable = true;
                  });
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(designationValue),
                    if (salaryValue.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '₹$salaryValue/day',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (String? value) {
              setState(() {
                _selectedDesignation = value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSalaryField(Color primaryColor) {
    return _buildCustomTextField(
      controller: _salaryController,
      label: 'Daily Wage Rate (₹) *',
      icon: Icons.payments_outlined,
      keyboardType: TextInputType.number,
      prefixText: '₹ ',
      readOnly: !_isSalaryEditable,
      suffixIcon: IconButton(
        icon: Icon(
          _isSalaryEditable
              ? Icons.lock_open_rounded
              : Icons.edit_note_rounded,
          size: 20,
          color: _isSalaryEditable ? primaryColor : Colors.grey[400],
        ),
        onPressed: () {
          setState(() {
            _isSalaryEditable = !_isSalaryEditable;
          });
        },
        tooltip: 'Toggle manual edit',
      ),
    );
  }

  Widget _buildWorkersListTab(Color primaryColor) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              // Search Input Box
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
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim().toLowerCase();
                    });
                  },
                  style: const TextStyle(
                    color: Color(0xFF0A183D),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search worker name, ID, phone, designation...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: primaryColor,
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear_rounded,
                              color: Color(0xFF64748B),
                              size: 18,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Designation Filter Chips
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildFilterChip('All', primaryColor),
                    ..._designations.map((d) {
                      final title = d['designation']?.toString() ?? '';
                      if (title.isEmpty) return const SizedBox.shrink();
                      return _buildFilterChip(title, primaryColor);
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Stream Directory List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirestoreService.getCollection(
              'workersConfig',
            ).orderBy('workerId').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: primaryColor),
                );
              }

              final allWorkers = snapshot.data!.docs;

              final filteredWorkers = allWorkers.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = (data['name'] ?? '').toString().toLowerCase();
                final id = (data['workerId'] ?? doc.id).toString().toLowerCase();
                final phone = (data['phoneNumber'] ?? '').toString().toLowerCase();
                final des = (data['designation'] ?? '').toString().toLowerCase();

                final matchesSearch = _searchQuery.isEmpty ||
                    name.contains(_searchQuery) ||
                    id.contains(_searchQuery) ||
                    phone.contains(_searchQuery) ||
                    des.contains(_searchQuery);

                final matchesFilter = _selectedFilterDesignation == 'All' ||
                    des == _selectedFilterDesignation.toLowerCase();

                return matchesSearch && matchesFilter;
              }).toList();

              if (filteredWorkers.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.people_outline_rounded,
                            size: 48,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No Workers Found',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0A183D),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No registered workers match "$_searchQuery"'
                              : 'Click REGISTER WORKER to add worker profiles.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 80),
                physics: const BouncingScrollPhysics(),
                itemCount: filteredWorkers.length,
                itemBuilder: (context, index) {
                  final doc = filteredWorkers[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final docId = doc.id;
                  final isEditing = _isEditing[docId] ?? false;

                  return _buildWorkerCard(data, docId, isEditing, primaryColor);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWorkerCard(
    Map<String, dynamic> data,
    String docId,
    bool isEditing,
    Color primaryColor,
  ) {
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
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _getInitials(data['name'] ?? 'W'),
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['name'] ?? 'Unnamed Worker',
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0A183D),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
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
                            'ID: ${data['workerId'] ?? docId}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        if (data['designation'] != null &&
                            data['designation'].toString().isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              data['designation'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2563EB),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (!isEditing)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.edit_rounded,
                        size: 20,
                        color: primaryColor,
                      ),
                      onPressed: () => _startEditing(docId, data),
                      tooltip: 'Edit Worker',
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: Color(0xFFEF4444),
                      ),
                      onPressed: () => _showDeleteDialog(docId),
                      tooltip: 'Delete Worker',
                    ),
                  ],
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.check_circle_rounded,
                        size: 22,
                        color: Color(0xFF16A34A),
                      ),
                      onPressed: () => _saveEditing(docId),
                      tooltip: 'Save',
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.cancel_rounded,
                        size: 22,
                        color: Color(0xFF64748B),
                      ),
                      onPressed: () => _cancelEditing(docId),
                      tooltip: 'Cancel',
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 10),
          if (isEditing)
            _buildEditableFields(docId, data)
          else
            _buildReadOnlyFields(data),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, Color primaryColor) {
    final isSelected = _selectedFilterDesignation == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? Colors.white : const Color(0xFF0A183D),
        ),
        selectedColor: primaryColor,
        backgroundColor: Colors.white,
        side: BorderSide(
          color: isSelected ? primaryColor : const Color(0xFFCBD5E1),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onSelected: (val) {
          setState(() {
            _selectedFilterDesignation = label;
          });
        },
      ),
    );
  }

  Widget _buildReadOnlyFields(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildInfoTile(
                Icons.phone_android_rounded,
                'Phone',
                data['phoneNumber'] ?? 'N/A',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildInfoTile(
                Icons.payments_rounded,
                'Daily Wage',
                '₹${data['salary']?.toString() ?? '0'}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildInfoTile(
                Icons.work_outline_rounded,
                'Designation',
                data['designation'] ?? 'N/A',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildInfoTile(
                Icons.calendar_month_rounded,
                'Joining Date',
                data['joiningDate'] ?? 'N/A',
              ),
            ),
          ],
        ),
        if (data['address'] != null &&
            data['address'].toString().isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildInfoTile(
            Icons.location_on_outlined,
            'Address',
            data['address'] ?? '',
          ),
        ],
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A183D),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableFields(String docId, Map<String, dynamic> data) {
    return Column(
      children: [
        _buildCustomTextField(
          controller: _editingControllers['${docId}_name']!,
          label: 'Full Name',
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 10),
        _buildCustomTextField(
          controller: _editingControllers['${docId}_phone']!,
          label: 'Phone Number (10 Digits)',
          icon: Icons.phone_android_rounded,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildCustomTextField(
                controller: _editingControllers['${docId}_salary']!,
                label: 'Daily Wage (₹)',
                icon: Icons.payments_outlined,
                keyboardType: TextInputType.number,
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildCustomTextField(
                controller: _editingControllers['${docId}_joiningDate']!,
                label: 'Joining Date',
                icon: Icons.calendar_month_rounded,
                readOnly: true,
                onTap: () => _selectDate(context, docId),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildCustomTextField(
          controller: _editingControllers['${docId}_address']!,
          label: 'Address',
          icon: Icons.location_on_outlined,
          maxLines: 2,
        ),
      ],
    );
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'W';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  void _showDeleteDialog(String docId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
              SizedBox(width: 8),
              Text(
                'Delete Worker Profile',
                style: TextStyle(
                  color: Color(0xFF0A183D),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to delete this worker registration? This action cannot be undone.',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'CANCEL',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _deleteWorker(docId);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('DELETE'),
            ),
          ],
        );
      },
    );
  }
}
