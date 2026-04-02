import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';

class WorkersConfigPage extends StatefulWidget {
  const WorkersConfigPage({super.key});

  @override
  _WorkersConfigPageState createState() => _WorkersConfigPageState();
}

class _WorkersConfigPageState extends State<WorkersConfigPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Removed _firestore field
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
    // Dispose all editing controllers
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

      // Extract number and increment
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
        SnackBar(content: Text('Please fill all required fields')),
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

      // Clear form
      _nameController.clear();
      _phoneController.clear();
      _addressController.clear();
      _salaryController.clear();
      _joiningDateController.text = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime.now());
      if (!mounted) return;
      setState(() {
        _selectedDesignation = null;
        _isSalaryEditable = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Worker created successfully')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Worker updated successfully')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating worker: $e')));
    }
  }

  Future<void> _deleteWorker(String docId) async {
    try {
      await FirestoreService.getCollection('workersConfig').doc(docId).delete();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Worker deleted successfully')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting worker: $e')));
    }
  }

  void _startEditing(String docId, Map<String, dynamic> workerData) {
    setState(() {
      _isEditing[docId] = true;
      // Initialize editing controllers with current data
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
      // Dispose editing controllers for this worker
      _editingControllers.remove('${docId}_name')?.dispose();
      _editingControllers.remove('${docId}_phone')?.dispose();
      _editingControllers.remove('${docId}_address')?.dispose();
      _editingControllers.remove('${docId}_joiningDate')?.dispose();
      _editingControllers.remove('${docId}_salary')?.dispose();
    });
  }

  void _saveEditing(String docId) {
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
    return GlassScaffold(
      title: 'Workers Configuration',
      onBack: () => Navigator.pop(context),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        tabs: const [
          Tab(text: 'Create New'),
          Tab(text: 'Workers List'),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Create New Worker Tab
          _buildCreateWorkerTab(),
          // Workers List Tab
          _buildWorkersListTab(),
        ],
      ),
    );
  }

  Widget _buildCreateWorkerTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.0),
      child: Column(
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Add New Worker',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 20),
                  _buildTextFieldWithIcon(
                    controller: _nameController,
                    labelText: 'Name *',
                    icon: Icons.person,
                  ),
                  SizedBox(height: 16),
                  _buildTextFieldWithIcon(
                    controller: _phoneController,
                    labelText: 'Phone Number *',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonFormField<String>(
                        value: _selectedDesignation,
                        decoration: InputDecoration(
                          labelText: 'Designation *',
                          border: InputBorder.none,
                          icon: Icon(Icons.work, color: Colors.grey.shade600),
                        ),
                        items: _designations.isNotEmpty
                            ? _designations.map<DropdownMenuItem<String>>((
                                designation,
                              ) {
                                final designationValue =
                                    designation['designation']?.toString() ??
                                    '';
                                final salaryValue =
                                    designation['salary']?.toString() ?? '';

                                return DropdownMenuItem<String>(
                                  value: designationValue.isEmpty
                                      ? null
                                      : designationValue,
                                  child: Text(designationValue),
                                  onTap: () {
                                    setState(() {
                                      _salaryController.text = salaryValue;
                                      _isSalaryEditable =
                                          false; // Reset to non-editable when new designation selected
                                    });
                                  },
                                );
                              }).toList()
                            : [],
                        onChanged: (String? value) {
                          setState(() {
                            _selectedDesignation = value;
                          });
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildSalaryField(),
                  SizedBox(height: 16),
                  _buildTextFieldWithIcon(
                    controller: _joiningDateController,
                    labelText: 'Joining Date',
                    icon: Icons.calendar_today,
                    isReadOnly: true,
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
                  SizedBox(height: 16),
                  _buildTextFieldWithIcon(
                    controller: _addressController,
                    labelText: 'Address',
                    icon: Icons.location_on,
                    maxLines: 3,
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _createWorker,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      minimumSize: Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      'Create Worker',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryField() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: _isSalaryEditable
              ? colorScheme.primary
              : const Color(0xFFE2E8F0),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _salaryController,
              decoration: InputDecoration(
                labelText: 'Salary *',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                icon: const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Icon(
                    Icons.attach_money_rounded,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              keyboardType: TextInputType.number,
              readOnly: !_isSalaryEditable,
              style: TextStyle(
                color: _isSalaryEditable
                    ? const Color(0xFF1E293B)
                    : const Color(0xFF64748B),
                fontWeight: _isSalaryEditable
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _isSalaryEditable ? Icons.lock_open_rounded : Icons.edit_rounded,
              color: _isSalaryEditable
                  ? colorScheme.primary
                  : const Color(0xFF64748B),
            ),
            onPressed: () {
              setState(() {
                _isSalaryEditable = !_isSalaryEditable;
              });
            },
            tooltip: _isSalaryEditable ? 'Lock salary field' : 'Edit salary',
          ),
        ],
      ),
    );
  }

  Widget _buildTextFieldWithIcon({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    bool isReadOnly = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          icon: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Icon(icon, color: const Color(0xFF64748B), size: 20),
          ),
        ),
        readOnly: isReadOnly,
        keyboardType: keyboardType,
        maxLines: maxLines,
        onTap: onTap,
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
          return Center(child: CircularProgressIndicator());
        }

        final workers = snapshot.data!.docs;

        if (workers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No workers found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: workers.length,
          itemBuilder: (context, index) {
            final doc = workers[index];
            final data = doc.data() as Map<String, dynamic>;
            final docId = doc.id;
            final workerId = data['workerId'] ?? docId;
            final isEditing = _isEditing[docId] ?? false;

            return Container(
              margin: EdgeInsets.only(bottom: 12),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Worker ID Header
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'ID: $workerId',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      SizedBox(height: 12),

                      if (isEditing) _buildEditableFields(docId, data),
                      if (!isEditing) _buildReadOnlyFields(data),

                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!isEditing) ...[
                            _buildActionButton(
                              icon: Icons.edit,
                              color: Colors.blue,
                              onPressed: () => _startEditing(docId, data),
                              label: 'Edit',
                            ),
                            SizedBox(width: 8),
                            _buildActionButton(
                              icon: Icons.delete,
                              color: Colors.red,
                              onPressed: () => _showDeleteDialog(docId),
                              label: 'Delete',
                            ),
                          ],
                          if (isEditing) ...[
                            _buildActionButton(
                              icon: Icons.cancel,
                              color: Colors.grey,
                              onPressed: () => _cancelEditing(docId),
                              label: 'Cancel',
                            ),
                            SizedBox(width: 8),
                            _buildActionButton(
                              icon: Icons.save,
                              color: Colors.green,
                              onPressed: () => _saveEditing(docId),
                              label: 'Save',
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String label,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildReadOnlyFields(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.person, size: 16, color: Colors.grey),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                data['name'] ?? '',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        _buildInfoRow(Icons.phone, data['phoneNumber'] ?? ''),
        _buildInfoRow(Icons.work, '${data['designation'] ?? ''}'),
        _buildInfoRow(Icons.attach_money, data['salary']?.toString() ?? ''),
        _buildInfoRow(Icons.calendar_today, data['joiningDate'] ?? ''),
        if (data['address'] != null && data['address'].isNotEmpty)
          _buildInfoRow(Icons.location_on, data['address'] ?? ''),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableFields(String docId, Map<String, dynamic> data) {
    return Column(
      children: [
        _buildEditableField(
          controller: _editingControllers['${docId}_name']!,
          label: 'Name',
          icon: Icons.person,
        ),
        SizedBox(height: 8),
        _buildEditableField(
          controller: _editingControllers['${docId}_phone']!,
          label: 'Phone Number',
          icon: Icons.phone,
          keyboardType: TextInputType.phone,
        ),
        SizedBox(height: 8),
        _buildEditableField(
          controller: _editingControllers['${docId}_joiningDate']!,
          label: 'Joining Date',
          icon: Icons.calendar_today,
          isReadOnly: true,
          onTap: () => _selectDate(context, docId),
        ),
        SizedBox(height: 8),
        _buildEditableField(
          controller: _editingControllers['${docId}_salary']!,
          label: 'Salary',
          icon: Icons.attach_money,
          keyboardType: TextInputType.number,
        ),
        SizedBox(height: 8),
        _buildEditableField(
          controller: _editingControllers['${docId}_address']!,
          label: 'Address',
          icon: Icons.location_on,
          maxLines: 2,
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(Icons.work, size: 16),
              SizedBox(width: 8),
              Text(
                'Designation: ${data['designation'] ?? ''}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditableField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isReadOnly = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color.fromARGB(255, 44, 88, 172)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          icon: Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(
              icon,
              size: 18,
              color: const Color.fromARGB(255, 16, 54, 124),
            ),
          ),
        ),
        readOnly: isReadOnly,
        keyboardType: keyboardType,
        maxLines: maxLines,
        onTap: onTap,
      ),
    );
  }

  void _showDeleteDialog(String docId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('Delete Worker'),
            ],
          ),
          content: Text(
            'Are you sure you want to delete this worker? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _deleteWorker(docId);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
