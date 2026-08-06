import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_text_field.dart';
import '../widgets/glass_button.dart';
import '../utils/dialog_utils.dart';

class WorkersConfigPage extends StatefulWidget {
  const WorkersConfigPage({super.key});

  @override
  _WorkersConfigPageState createState() => _WorkersConfigPageState();
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
  String? _selectedDesignation;
  bool _isSalaryEditable = false;

  // Editing controllers for Workers List tab
  final Map<String, TextEditingController> _editingControllers = {};
  final Map<String, bool> _isEditing = {};

  List<Map<String, dynamic>> _designations = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDesignations();
    _joiningDateController.text = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _joiningDateController.dispose();
    _salaryController.dispose();
    for (var controller in _editingControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDesignations() async {
    try {
      final querySnapshot = await FirestoreService.getCollection(
        'labours',
      ).get();
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
      print('Error loading designations: $e');
    }
  }

  Future<String> _getNextWorkerId() async {
    try {
      final querySnapshot = await FirestoreService.getCollection(
        'workersConfig',
      ).orderBy('workerId', descending: true).limit(1).get();

      if (querySnapshot.docs.isEmpty) {
        return 'WC001';
      }

      final lastWorker = querySnapshot.docs.first;
      final lastWorkerId = lastWorker['workerId'] as String? ?? 'WC000';

      final numberStr = lastWorkerId.replaceAll(RegExp(r'[^0-9]'), '');
      final nextNumber = (int.tryParse(numberStr) ?? 0) + 1;

      return 'WC${nextNumber.toString().padLeft(3, '0')}';
    } catch (e) {
      print('Error generating worker ID: $e');
      return 'WC001';
    }
  }

  Future<void> _createWorker() async {
    if (_nameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _selectedDesignation == null ||
        _salaryController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    if (_phoneController.text.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number must be exactly 10 digits')),
      );
      return;
    }

    try {
      final workerId = await _getNextWorkerId();

      await FirestoreService.getCollection('workersConfig').doc(workerId).set({
        'workerId': workerId,
        'name': _nameController.text,
        'phoneNumber': _phoneController.text,
        'designation': _selectedDesignation,
        'salary': _salaryController.text,
        'joiningDate': _joiningDateController.text,
        'address': _addressController.text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _nameController.clear();
      _phoneController.clear();
      _addressController.clear();
      _salaryController.clear();
      _joiningDateController.text = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime.now());
      if (mounted) {
        setState(() {
          _selectedDesignation = null;
          _isSalaryEditable = false;
        });
      }

      if (mounted) {
        await DialogUtils.showSuccessDialog(
          context,
          message: 'Worker created successfully!',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error creating worker: $e')));
    }
  }

  Future<void> _updateWorker(
    String docId,
    Map<String, dynamic> updatedData,
  ) async {
    try {
      await FirestoreService.getCollection(
        'workersConfig',
      ).doc(docId).update(updatedData);
      if (mounted) {
        await DialogUtils.showSuccessDialog(
          context,
          message: 'Worker updated successfully!',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating worker: $e')));
    }
  }

  Future<void> _deleteWorker(String docId) async {
    try {
      await FirestoreService.getCollection('workersConfig').doc(docId).delete();
      if (mounted) {
        await DialogUtils.showSuccessDialog(
          context,
          message: 'Worker deleted successfully!',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting worker: $e')));
    }
  }

  void _startEditing(String docId, Map<String, dynamic> workerData) {
    setState(() {
      _isEditing[docId] = true;
      _editingControllers['${docId}_name'] = TextEditingController(
        text: workerData['name'] ?? '',
      );
      _editingControllers['${docId}_phone'] = TextEditingController(
        text: workerData['phoneNumber'] ?? '',
      );
      _editingControllers['${docId}_address'] = TextEditingController(
        text: workerData['address'] ?? '',
      );
      _editingControllers['${docId}_joiningDate'] = TextEditingController(
        text: workerData['joiningDate'] ?? '',
      );
      _editingControllers['${docId}_salary'] = TextEditingController(
        text: workerData['salary']?.toString() ?? '',
      );
    });
  }

  void _cancelEditing(String docId) {
    setState(() {
      _isEditing[docId] = false;
      _editingControllers.remove('${docId}_name')?.dispose();
      _editingControllers.remove('${docId}_phone')?.dispose();
      _editingControllers.remove('${docId}_address')?.dispose();
      _editingControllers.remove('${docId}_joiningDate')?.dispose();
      _editingControllers.remove('${docId}_salary')?.dispose();
    });
  }

  void _saveEditing(String docId) {
    final phone = _editingControllers['${docId}_phone']?.text ?? '';
    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number must be exactly 10 digits')),
      );
      return;
    }

    final updatedData = {
      'name': _editingControllers['${docId}_name']?.text ?? '',
      'phoneNumber': _editingControllers['${docId}_phone']?.text ?? '',
      'address': _editingControllers['${docId}_address']?.text ?? '',
      'joiningDate': _editingControllers['${docId}_joiningDate']?.text ?? '',
      'salary': _editingControllers['${docId}_salary']?.text ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    _updateWorker(docId, updatedData);
    _cancelEditing(docId);
  }

  Future<void> _selectDate(BuildContext context, String docId) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _editingControllers['${docId}_joiningDate']?.text = DateFormat(
          'yyyy-MM-dd',
        ).format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 600;

    return GlassScaffold(
      title: 'Workers Configuration',
      onBack: () => Navigator.pop(context),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        tabs: const [
          Tab(text: 'CREATE NEW'),
          Tab(text: 'WORKERS LIST'),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
            child: TabBarView(
          controller: _tabController,
          children: [_buildCreateWorkerTab(), _buildWorkersListTab()],
        ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateWorkerTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Basic Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 20),
                GlassTextField(
                  controller: _nameController,
                  label: 'Full Name *',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
                GlassTextField(
                  controller: _phoneController,
                  label: 'Phone Number *',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Job Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),
                _buildDesignationDropdown(),
                const SizedBox(height: 16),
                _buildSalaryField(),
                const SizedBox(height: 16),
                GlassTextField(
                  controller: _joiningDateController,
                  label: 'Joining Date',
                  icon: Icons.calendar_today_outlined,
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
                const SizedBox(height: 24),
                const Text(
                  'Additional Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),
                GlassTextField(
                  controller: _addressController,
                  label: 'Address',
                  icon: Icons.location_on_outlined,
                  maxLines: 3,
                ),
                const SizedBox(height: 32),
                GlassButton(
                  label: 'CREATE WORKER',
                  onPressed: _createWorker,
                  icon: Icons.add_circle_outline,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesignationDropdown() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Designation *',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedDesignation,
            isExpanded: true,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              prefixIcon: Icon(
                Icons.work_outline,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
            hint: const Text('Select Designation'),
            dropdownColor: theme.cardColor,
            items: _designations.map<DropdownMenuItem<String>>((designation) {
              final designationValue =
                  designation['designation']?.toString() ?? '';
              final salaryValue = designation['salary']?.toString() ?? '';

              return DropdownMenuItem<String>(
                value: designationValue.isEmpty ? null : designationValue,
                child: Text(designationValue),
                onTap: () {
                  setState(() {
                    _salaryController.text = salaryValue;
                    // Keep it editable or set to true if we want to allow immediate override
                    _isSalaryEditable = true;
                  });
                },
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

  Widget _buildSalaryField() {
    final theme = Theme.of(context);
    return GlassTextField(
      controller: _salaryController,
      label: 'Salary *',
      icon: Icons.attach_money_rounded,
      keyboardType: TextInputType.number,
      prefixText: '₹ ',
      readOnly: !_isSalaryEditable,
      enabled: true,
      suffixIcon: IconButton(
        icon: Icon(
          _isSalaryEditable ? Icons.edit_off_rounded : Icons.edit_rounded,
          size: 20,
          color: _isSalaryEditable ? theme.colorScheme.primary : Colors.grey,
        ),
        onPressed: () {
          setState(() {
            _isSalaryEditable = !_isSalaryEditable;
          });
        },
      ),
    );
  }

  Widget _buildWorkersListTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.getCollection(
        'workersConfig',
      ).orderBy('workerId').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final workers = snapshot.data!.docs;

        if (workers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No workers found',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: workers.length,
          itemBuilder: (context, index) {
            final doc = workers[index];
            final data = doc.data() as Map<String, dynamic>;
            final docId = doc.id;
            final isEditing = _isEditing[docId] ?? false;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'ID: ${data['workerId'] ?? docId}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        if (!isEditing)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 20,
                                  color: Colors.blue,
                                ),
                                onPressed: () => _startEditing(docId, data),
                                tooltip: 'Edit',
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: Colors.red,
                                ),
                                onPressed: () => _showDeleteDialog(docId),
                                tooltip: 'Delete',
                              ),
                            ],
                          )
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  size: 20,
                                  color: Colors.green,
                                ),
                                onPressed: () => _saveEditing(docId),
                                tooltip: 'Save',
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.cancel_outlined,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                                onPressed: () => _cancelEditing(docId),
                                tooltip: 'Cancel',
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (isEditing)
                      _buildEditableFields(docId, data)
                    else
                      _buildReadOnlyFields(data),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReadOnlyFields(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data['name'] ?? '',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.phone_outlined, data['phoneNumber'] ?? ''),
        _buildInfoRow(Icons.work_outline, '${data['designation'] ?? ''}'),
        _buildInfoRow(
          Icons.attach_money_rounded,
          'Salary: ₹${data['salary']?.toString() ?? '0'}',
        ),
        _buildInfoRow(
          Icons.calendar_today_outlined,
          'Joined: ${data['joiningDate'] ?? 'N/A'}',
        ),
        if (data['address'] != null && data['address'].isNotEmpty)
          _buildInfoRow(Icons.location_on_outlined, data['address'] ?? ''),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableFields(String docId, Map<String, dynamic> data) {
    return Column(
      children: [
        GlassTextField(
          controller: _editingControllers['${docId}_name']!,
          label: 'Name',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 12),
        GlassTextField(
          controller: _editingControllers['${docId}_phone']!,
          label: 'Phone Number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
        ),
        const SizedBox(height: 12),
        GlassTextField(
          controller: _editingControllers['${docId}_joiningDate']!,
          label: 'Joining Date',
          icon: Icons.calendar_today_outlined,
          readOnly: true,
          onTap: () => _selectDate(context, docId),
        ),
        const SizedBox(height: 12),
        GlassTextField(
          controller: _editingControllers['${docId}_salary']!,
          label: 'Salary',
          icon: Icons.attach_money_rounded,
          keyboardType: TextInputType.number,
          prefixText: '₹ ',
        ),
        const SizedBox(height: 12),
        GlassTextField(
          controller: _editingControllers['${docId}_address']!,
          label: 'Address',
          icon: Icons.location_on_outlined,
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              const Icon(Icons.work_outline, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                'Designation: ${data['designation'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showDeleteDialog(String docId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Delete Worker'),
            ],
          ),
          content: const Text(
            'Are you sure you want to delete this worker? This action cannot be undone.',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                _deleteWorker(docId);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
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
