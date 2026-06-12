import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:demo_cst/services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';
import '../utils/dialog_utils.dart';

class VehicleDriverConfigPage extends StatefulWidget {
  const VehicleDriverConfigPage({super.key});

  @override
  State<VehicleDriverConfigPage> createState() =>
      _VehicleDriverConfigPageState();
}

class _VehicleDriverConfigPageState extends State<VehicleDriverConfigPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _driverNameController = TextEditingController();
  final TextEditingController _driverPhoneController = TextEditingController();
  final TextEditingController _driverAddressController =
      TextEditingController();
  final TextEditingController _driverLicenseController =
      TextEditingController();
  final TextEditingController _experienceController = TextEditingController();

  String _driverStatus = 'Active';
  String _currentDriverId = '';
  bool _isEditing = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<String> _getNextDriverId() async {
    final snapshot = await FirestoreService
        .getCollection('drivers')
        .orderBy('driverId', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return 'DV001';
    }

    final lastDriverId = snapshot.docs.first['driverId'] as String? ?? 'DV000';
    final numberStr = lastDriverId.replaceAll(RegExp(r'[^0-9]'), '');
    final number = int.tryParse(numberStr) ?? 0;
    return 'DV${(number + 1).toString().padLeft(3, '0')}';
  }

  Future<void> _saveDriver() async {
    if (!_formKey.currentState!.validate()) return;

    final driverId = _isEditing ? _currentDriverId : await _getNextDriverId();

    final data = {
      'driverId': driverId,
      'driverName': _driverNameController.text.trim(),
      'driverPhone': _driverPhoneController.text.trim(),
      'driverAddress': _driverAddressController.text.trim(),
      'driverLicense': _driverLicenseController.text.trim(),
      'experience': _experienceController.text.trim(),
      'status': _driverStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!_isEditing) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await FirestoreService
        .getCollection('drivers')
        .doc(driverId)
        .set(data);

    if (mounted) {
      await DialogUtils.showSuccessDialog(
        context,
        message: 'Driver ${_isEditing ? 'updated' : 'saved'} successfully!',
      );
    }

    if (!_isEditing) {
      _resetForm();
      // Switch to existing drivers tab after saving new driver
      _tabController.animateTo(1);
    }
  }

  void _editDriver(DocumentSnapshot driver) {
    setState(() {
      _isEditing = true;
      _currentDriverId = driver['driverId'];
      _driverNameController.text = driver['driverName'] ?? '';
      _driverPhoneController.text = driver['driverPhone'] ?? '';
      _driverAddressController.text = driver['driverAddress'] ?? '';
      _driverLicenseController.text = driver['driverLicense'] ?? '';
      _experienceController.text = driver['experience'] ?? '';
      _driverStatus = driver['status'] ?? 'Active';
    });

    // Switch to new driver tab for editing
    _tabController.animateTo(0);
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _isEditing = false;
      _currentDriverId = '';
      _driverStatus = 'Active';
    });
  }

  Future<void> _deleteDriver(String driverId) async {
    final result = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Driver'),
        content: const Text('Are you sure you want to delete this driver?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (result == true) {
      await FirestoreService
          .getCollection('drivers')
          .doc(driverId)
          .delete();

      if (mounted) {
        await DialogUtils.showSuccessDialog(
          context,
          message: 'Driver deleted successfully!',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: GlassScaffold(
        title: 'Driver Configuration',
        onBack: () => Navigator.pop(context),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.person_add), text: 'New Driver'),
            Tab(icon: Icon(Icons.people), text: 'Existing Drivers'),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // New Driver Tab
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _isEditing ? Icons.edit : Icons.person_add,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isEditing
                                      ? 'Edit Driver - $_currentDriverId'
                                      : 'Add New Driver',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _driverNameController,
                              decoration: const InputDecoration(
                                labelText: 'Driver Name',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person),
                              ),
                              validator: (v) =>
                                  v!.isEmpty ? 'Enter driver name' : null,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _driverPhoneController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.phone),
                              ),
                              inputFormatters: [
                                // Allow only numbers and limit to 10 digits
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Enter phone number';
                                } else if (!RegExp(r'^\d+$').hasMatch(v)) {
                                  return 'Only numbers are allowed';
                                } else if (v.length != 10) {
                                  return 'Phone number must be 10 digits';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),

                            TextFormField(
                              controller: _driverLicenseController,
                              decoration: const InputDecoration(
                                labelText: 'License Number',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.card_membership),
                              ),
                              validator: (v) =>
                                  v!.isEmpty ? 'Enter license number' : null,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _experienceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Experience (years)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.work),
                              ),
                              validator: (v) =>
                                  v!.isEmpty ? 'Enter experience' : null,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _driverAddressController,
                              decoration: const InputDecoration(
                                labelText: 'Address',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.location_on),
                              ),
                              maxLines: 2,
                              validator: (v) =>
                                  v!.isEmpty ? 'Enter address' : null,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Text(
                                  'Status:',
                                  style: TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 20),
                                DropdownButton<String>(
                                  value: _driverStatus,
                                  items: ['Active', 'Inactive']
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(e),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) =>
                                      setState(() => _driverStatus = val!),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saveDriver,
                            icon: Icon(
                              _isEditing ? Icons.save : Icons.person_add,
                            ),
                            label: Text(
                              _isEditing ? 'Update Driver' : 'Save Driver',
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        if (_isEditing) ...[
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: _resetForm,
                            icon: const Icon(Icons.cancel),
                            label: const Text('Cancel'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (_isEditing) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Note: Click "Update Driver" to save changes',
                        style: TextStyle(
                          color: Colors.orange,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Existing Drivers Tab
            StreamBuilder<QuerySnapshot>(
              stream: FirestoreService
                  .getCollection('drivers')
                  .orderBy('driverId')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final drivers = snapshot.data!.docs;

                if (drivers.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No drivers found',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        Text(
                          'Add a new driver in the "New Driver" tab',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: drivers.length,
                  itemBuilder: (context, index) {
                    final driver = drivers[index];
                    final data = driver.data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: Text(
                            data['driverId']?.toString().substring(2) ?? '',
                            style: const TextStyle(),
                          ),
                        ),
                        title: Text(
                          data['driverName'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Phone: ${data['driverPhone'] ?? ''}'),
                            Text('License: ${data['driverLicense'] ?? ''}'),
                            Text(
                              'Experience: ${data['experience'] ?? '0'} years',
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        (data['status'] ?? 'Active') == 'Active'
                                        ? Colors.green.withOpacity(0.2)
                                        : Colors.red.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    data['status'] ?? 'Active',
                                    style: TextStyle(
                                      color:
                                          (data['status'] ?? 'Active') ==
                                              'Active'
                                          ? Colors.green
                                          : Colors.red,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _editDriver(driver),
                              icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
                              tooltip: 'Edit Driver',
                            ),
                            IconButton(
                              onPressed: () => _deleteDriver(data['driverId']),
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Delete Driver',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
