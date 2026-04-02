import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';

class AddVehicleLogPage extends StatefulWidget {
  const AddVehicleLogPage({super.key});

  @override
  State<AddVehicleLogPage> createState() => _AddVehicleLogPageState();
}

class _AddVehicleLogPageState extends State<AddVehicleLogPage> {
  final _formKey = GlobalKey<FormState>();
  // Removed _firestore field

  final TextEditingController _fromLocationController = TextEditingController();
  final TextEditingController _toLocationController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();

  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  String _movementType = 'Company → Site';
  DateTime _selectedDate = DateTime.now();
  List<String> _driverNames = [];
  List<String> _siteNames = [];
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _materials = [];
  String? _selectedDriver;
  String? _selectedFromSite;
  String? _selectedToSite;
  String? _selectedVehicle;
  String? _selectedMaterial;
  String _selectedUnit = '';
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _setCurrentTime();
    _loadInitialData();
  }

  void _setCurrentTime() {
    final now = DateTime.now();
    _startTimeController.text = DateFormat('HH:mm').format(now);
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _loadDrivers(),
        _loadSites(),
        _loadVehicles(),
        _loadMaterials(),
      ]);
    } catch (e) {
      print('Error loading initial data: $e');
      _showErrorSnackBar('Failed to load data. Please try again.');
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDrivers() async {
    try {
      final snapshot = await FirestoreService.getCollection(
        'drivers',
      ).where('status', isEqualTo: 'Active').get();

      final names = snapshot.docs
          .map((doc) => doc['driverName'] as String? ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _driverNames = names;
      });
    } catch (e) {
      print('Error loading drivers: $e');
      rethrow;
    }
  }

  Future<void> _loadSites() async {
    try {
      final snapshot = await FirestoreService.getCollection('projects').get();

      setState(() {
        _siteNames = snapshot.docs
            .map((doc) {
              final data = doc.data();
              final siteName =
                  data['siteName'] ??
                  data['name'] ??
                  data['projectName'] ??
                  data['site'] ??
                  '';
              return siteName.toString();
            })
            .where((name) => name.isNotEmpty)
            .toList();
      });
    } catch (e) {
      print('Error loading sites: $e');
      rethrow;
    }
  }

  Future<void> _loadVehicles() async {
    try {
      final snapshot = await FirestoreService.getCollection(
        'vehicleDetails',
      ).get();

      List<Map<String, dynamic>> vehicles = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final vehicleId = data['id'] as String? ?? '';
        final modelName = data['modelName'] as String? ?? '';

        if (vehicleId.isNotEmpty && modelName.isNotEmpty) {
          vehicles.add({
            'id': vehicleId,
            'modelName': modelName,
            'numberPlate': data['numberPlate'] as String? ?? '',
          });
        }
      }

      vehicles.sort((a, b) => a['id'].compareTo(b['id']));

      setState(() {
        _vehicles = vehicles;
      });
    } catch (e) {
      print('Error loading vehicles: $e');
      rethrow;
    }
  }

  Future<void> _loadMaterials() async {
    try {
      final snapshot = await FirestoreService.getCollection('materials').get();

      List<Map<String, dynamic>> materialsWithUnits = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final materialName = data['materialName'] as String? ?? '';
        final materialUnitRef = data['materialUnit'] as DocumentReference?;

        String unit = '';

        if (materialUnitRef != null) {
          try {
            final unitDoc = await materialUnitRef.get();
            if (unitDoc.exists) {
              unit = unitDoc['unitName'] as String? ?? '';
            }
          } catch (e) {
            print('Error fetching unit for material $materialName: $e');
          }
        }

        materialsWithUnits.add({
          'materialName': materialName,
          'unit': unit,
          'id': doc.id,
        });
      }

      setState(() {
        _materials = materialsWithUnits;
      });
    } catch (e) {
      print('Error loading materials: $e');
      rethrow;
    }
  }

  Future<String> _getNextMovementId() async {
    try {
      final snapshot = await FirestoreService.getCollection(
        'vehicleMovements',
      ).orderBy('movementId', descending: true).limit(1).get();

      if (snapshot.docs.isEmpty) {
        return 'VM001';
      }

      final lastMovementId =
          snapshot.docs.first['movementId'] as String? ?? 'VM000';
      final numberStr = lastMovementId.replaceAll(RegExp(r'[^0-9]'), '');
      final nextNumber = (int.tryParse(numberStr) ?? 0) + 1;
      return 'VM${nextNumber.toString().padLeft(3, '0')}';
    } catch (e) {
      print('Error generating movement ID: $e');
      return 'VM001';
    }
  }

  void _onMaterialSelected(String? materialName) {
    setState(() {
      _selectedMaterial = materialName;
      _selectedUnit = '';

      if (materialName != null && materialName.isNotEmpty) {
        final selectedMaterial = _materials.firstWhere(
          (material) =>
              (material['materialName'] as String? ?? '') == materialName,
          orElse: () => {},
        );

        if (selectedMaterial.isNotEmpty) {
          _selectedUnit = selectedMaterial['unit'] as String? ?? '';
        }
      }
    });
  }

  void _updateLocationFields() {
    setState(() {
      switch (_movementType) {
        case 'Company → Site':
          _fromLocationController.text = 'Company';
          _selectedFromSite = null;
          _selectedToSite = null;
          break;
        case 'Site → Site':
          _fromLocationController.text = '';
          _selectedFromSite = null;
          _selectedToSite = null;
          break;
        case 'Site → Company':
          _toLocationController.text = 'Company';
          _selectedFromSite = null;
          _selectedToSite = null;
          break;
      }
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final movementId = await _getNextMovementId();
      final dateFormatted = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final timestamp = FieldValue.serverTimestamp();

      // Create a unique document ID
      final docId =
          '${movementId}_${_selectedVehicle}_${DateTime.now().millisecondsSinceEpoch}';

      String fromLocation = '';
      String toLocation = '';

      // Determine locations based on movement type
      switch (_movementType) {
        case 'Company → Site':
          fromLocation = 'Company';
          toLocation = _selectedToSite ?? '';
          break;
        case 'Site → Site':
          fromLocation = _selectedFromSite ?? '';
          toLocation = _selectedToSite ?? '';
          break;
        case 'Site → Company':
          fromLocation = _selectedFromSite ?? '';
          toLocation = 'Company';
          break;
      }

      // Get selected vehicle details for additional info
      final selectedVehicle = _vehicles.firstWhere(
        (v) => v['id'] == _selectedVehicle,
        orElse: () => {'id': '', 'modelName': '', 'numberPlate': ''},
      );

      // Complete movement data for Firestore
      final movementData = {
        // Basic Information
        'movementId': movementId,
        'docId': docId,
        'vehicleId': _selectedVehicle ?? '',
        'vehicleModel': selectedVehicle['modelName'] ?? '',
        'vehicleNumberPlate': selectedVehicle['numberPlate'] ?? '',
        'date': dateFormatted,
        'timestamp': _selectedDate,

        // Movement Details
        'movementType': _movementType,
        'fromLocation': fromLocation,
        'toLocation': toLocation,

        // Driver Information
        'driverName': _selectedDriver ?? '',

        // Time Information
        'startTime': _startTimeController.text.trim(),
        'endTime': _endTimeController.text.trim(),

        // Material Information
        'materialType': _selectedMaterial ?? '',
        'materialUnit': _selectedUnit,
        'quantity': _quantityController.text.trim(),
        'quantityValue': double.tryParse(_quantityController.text.trim()) ?? 0,

        // Distance Information
        'distanceKm': _distanceController.text.trim(),
        'distanceValue': double.tryParse(_distanceController.text.trim()) ?? 0,

        // Additional Information
        'remarks': _remarksController.text.trim(),

        // System Fields
        'createdAt': timestamp,
        'updatedAt': timestamp,
        'status': 'Active',
      };

      // Save to Firestore
      await FirestoreService.getCollection(
        'vehicleMovements',
      ).doc(docId).set(movementData);

      _showSuccessSnackBar('Vehicle movement logged successfully!');
      _resetForm();
    } catch (e) {
      print('Error saving movement: $e');
      _showErrorSnackBar('Failed to save movement: ${e.toString()}');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    setState(() {
      _movementType = 'Company → Site';
      _selectedDriver = null;
      _selectedFromSite = null;
      _selectedToSite = null;
      _selectedVehicle = null;
      _selectedMaterial = null;
      _selectedUnit = '';
      _selectedDate = DateTime.now();
    });
    _setCurrentTime();
    _startTimeController.clear();
    _endTimeController.clear();
    _quantityController.clear();
    _distanceController.clear();
    _remarksController.clear();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return GlassScaffold(
        title: 'Vehicle Movement Log',
        onBack: () => Navigator.pop(context),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading data...'),
            ],
          ),
        ),
      );
    }

    return GlassScaffold(
      title: 'Vehicle Movement Log',
      onBack: () => Navigator.pop(context),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadInitialData,
          tooltip: 'Reload Data',
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Information Card
              Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Basic Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Vehicle Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedVehicle,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: 'Select Vehicle',
                          prefixIcon: const Icon(Icons.local_shipping),
                          errorText: _vehicles.isEmpty
                              ? 'No vehicles available'
                              : null,
                        ),
                        items: _vehicles
                            .map<DropdownMenuItem<String>>(
                              (vehicle) => DropdownMenuItem<String>(
                                value: vehicle['id'],
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      vehicle['modelName'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    // Text(
                                    //   vehicle['modelName'],
                                    //   style: TextStyle(
                                    //     fontSize: 14,
                                    //
                                    //   ),
                                    // ),
                                    // if (vehicle['numberPlate'] != null &&
                                    //     vehicle['numberPlate']
                                    //         .toString()
                                    //         .isNotEmpty)
                                    //   Text(
                                    //     'Plate: ${vehicle['numberPlate']}',
                                    //     style: TextStyle(
                                    //       fontSize: 12,
                                    //
                                    //     ),
                                    //   ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _vehicles.isEmpty
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedVehicle = value;
                                });
                              },
                        validator: (value) =>
                            value == null ? 'Please select a vehicle' : null,
                        isExpanded: true,
                      ),
                      const SizedBox(height: 12),
                      // Selected Vehicle Info
                      if (_selectedVehicle != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Selected Vehicle:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _vehicles.firstWhere(
                                        (v) => v['id'] == _selectedVehicle,
                                        orElse: () => {
                                          'id': '',
                                          'modelName': '',
                                        },
                                      )['modelName'],
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      // Date Selection
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Date: ${DateFormat('MMM dd, yyyy').format(_selectedDate)}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _selectDate(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Change Date'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Movement Type Card
              Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Movement Type',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _movementType,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Select Movement Type',
                          prefixIcon: Icon(Icons.swap_horiz),
                        ),
                        items:
                            ['Company → Site', 'Site → Site', 'Site → Company']
                                .map<DropdownMenuItem<String>>(
                                  (type) => DropdownMenuItem<String>(
                                    value: type,
                                    child: Text(type),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          setState(() {
                            _movementType = value!;
                          });
                          _updateLocationFields();
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Locations Card
              Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Locations',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // From Location
                      if (_movementType != 'Company → Site')
                        Column(
                          children: [
                            DropdownButtonFormField<String>(
                              value: _selectedFromSite,
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: 'From Site',
                                prefixIcon: const Icon(Icons.location_on),
                                errorText: _siteNames.isEmpty
                                    ? 'No sites available'
                                    : null,
                              ),
                              items: _siteNames
                                  .map<DropdownMenuItem<String>>(
                                    (site) => DropdownMenuItem<String>(
                                      value: site,
                                      child: Text(site),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _siteNames.isEmpty
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _selectedFromSite = value;
                                      });
                                    },
                              validator: (value) {
                                if (_movementType != 'Company → Site' &&
                                    (value == null || value.isEmpty)) {
                                  return 'Please select from site';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),

                      // To Location
                      if (_movementType != 'Site → Company')
                        DropdownButtonFormField<String>(
                          value: _selectedToSite,
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            labelText: 'To Site',
                            prefixIcon: const Icon(Icons.location_on),
                            errorText: _siteNames.isEmpty
                                ? 'No sites available'
                                : null,
                          ),
                          items: _siteNames
                              .map<DropdownMenuItem<String>>(
                                (site) => DropdownMenuItem<String>(
                                  value: site,
                                  child: Text(site),
                                ),
                              )
                              .toList(),
                          onChanged: _siteNames.isEmpty
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedToSite = value;
                                  });
                                },
                          validator: (value) {
                            if (_movementType != 'Site → Company' &&
                                (value == null || value.isEmpty)) {
                              return 'Please select to site';
                            }
                            return null;
                          },
                        ),
                    ],
                  ),
                ),
              ),

              // Driver & Material Information Card
              Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Driver & Material',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Driver Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedDriver,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: 'Select Driver',
                          prefixIcon: const Icon(Icons.person),
                          errorText: _driverNames.isEmpty
                              ? 'No drivers available'
                              : null,
                        ),
                        items: _driverNames
                            .map<DropdownMenuItem<String>>(
                              (driver) => DropdownMenuItem<String>(
                                value: driver,
                                child: Text(driver),
                              ),
                            )
                            .toList(),
                        onChanged: _driverNames.isEmpty
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedDriver = value;
                                });
                              },
                        validator: (value) =>
                            value == null ? 'Please select a driver' : null,
                      ),
                      const SizedBox(height: 12),
                      // Material Information
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: _selectedMaterial,
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: 'Material Type',
                                prefixIcon: const Icon(Icons.inventory),
                                errorText: _materials.isEmpty
                                    ? 'No materials available'
                                    : null,
                              ),
                              items: _materials
                                  .map<DropdownMenuItem<String>>(
                                    (material) => DropdownMenuItem<String>(
                                      value:
                                          material['materialName'] as String? ??
                                          '',
                                      child: Text(
                                        material['materialName'] as String? ??
                                            '',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _materials.isEmpty
                                  ? null
                                  : _onMaterialSelected,
                              validator: (value) => value == null
                                  ? 'Please select a material'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: _quantityController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Quantity',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.scale),
                                suffixText: _selectedUnit.isNotEmpty
                                    ? _selectedUnit
                                    : null,
                                suffixStyle: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? 'Enter quantity'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      if (_selectedUnit.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Unit: $_selectedUnit',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Time & Distance Card
              Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Time & Distance',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _startTimeController,
                              decoration: const InputDecoration(
                                labelText: 'Start Time',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.access_time),
                                hintText: 'HH:mm',
                              ),
                              readOnly: true,
                              onTap: () {
                                _setCurrentTime();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _endTimeController,
                              decoration: const InputDecoration(
                                labelText: 'End Time',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.access_time),
                                hintText: 'HH:mm (e.g., 16:15)',
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? 'Enter end time'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _distanceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Distance (km)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.speed),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Enter distance'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),

              // Remarks Card
              Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Additional Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _remarksController,
                        decoration: const InputDecoration(
                          labelText: 'Remarks',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.note),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),

              // Submit Button
              Center(
                child: _isSubmitting
                    ? const Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Saving movement log...'),
                        ],
                      )
                    : ElevatedButton.icon(
                        onPressed: _submitForm,
                        icon: const Icon(Icons.save),
                        label: const Text('Save Movement Log'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
