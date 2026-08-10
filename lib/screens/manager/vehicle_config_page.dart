import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/utils/dialog_utils.dart';

class AddVehicleLogPage extends StatefulWidget {
  const AddVehicleLogPage({super.key});

  @override
  State<AddVehicleLogPage> createState() => _AddVehicleLogPageState();
}

class _AddVehicleLogPageState extends State<AddVehicleLogPage> {
  final _formKey = GlobalKey<FormState>();

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
    _startTimeController.text = DateFormat('hh:mm a').format(now);
  }

  Future<void> _selectTime(
    BuildContext context,
    TextEditingController controller,
  ) async {
    TimeOfDay initialTime = TimeOfDay.now();
    if (controller.text.isNotEmpty) {
      try {
        final parsedTime = DateFormat('hh:mm a').parse(controller.text);
        initialTime = TimeOfDay(
          hour: parsedTime.hour,
          minute: parsedTime.minute,
        );
      } catch (e) {
        try {
          final parsedTime = DateFormat('HH:mm').parse(controller.text);
          initialTime = TimeOfDay(
            hour: parsedTime.hour,
            minute: parsedTime.minute,
          );
        } catch (e) {
          // Keep current time
        }
      }
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (!mounted) return;
      final now = DateTime.now();
      final dt = DateTime(
        now.year,
        now.month,
        now.day,
        picked.hour,
        picked.minute,
      );
      setState(() {
        controller.text = DateFormat('hh:mm a').format(dt);
      });
    }
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
          .toSet()
          .toList();

      if (!mounted) return;
      setState(() {
        _driverNames = names;
        if (_selectedDriver != null &&
            !_driverNames.contains(_selectedDriver)) {
          _selectedDriver = null;
        }
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _loadSites() async {
    try {
      final snapshot = await FirestoreService.getCollection('projects').get();

      if (!mounted) return;
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
            .toSet()
            .toList();

        if (_selectedFromSite != null &&
            !_siteNames.contains(_selectedFromSite)) {
          _selectedFromSite = null;
        }
        if (_selectedToSite != null && !_siteNames.contains(_selectedToSite)) {
          _selectedToSite = null;
        }
      });
    } catch (e) {
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

      if (!mounted) return;
      setState(() {
        _vehicles = vehicles;
        if (_selectedVehicle != null &&
            !_vehicles.any((v) => v['id'] == _selectedVehicle)) {
          _selectedVehicle = null;
        }
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _loadMaterials() async {
    try {
      final snapshot = await FirestoreService.getCollection(
        'materialCategories',
      ).get();

      List<Map<String, dynamic>> materialsWithUnits = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final materialName = (data['matCategory'] ?? data['materialName'] ?? '')
            .toString()
            .trim();
        if (materialName.isEmpty) continue;
        final materialUnitRef = data['materialUnit'] as DocumentReference?;

        String unit = '';

        if (materialUnitRef != null) {
          try {
            final unitDoc = await materialUnitRef.get();
            if (unitDoc.exists) {
              final unitData = unitDoc.data() as Map<String, dynamic>?;
              unit =
                  (unitData?['unitName'] ??
                          unitData?['name'] ??
                          unitData?['matUnit'] ??
                          '')
                      .toString();
            }
          } catch (e) {
            // Ignore unit fetch error
          }
        }

        materialsWithUnits.add({
          'materialName': materialName,
          'unit': unit,
          'id': doc.id,
        });
      }

      if (!mounted) return;
      setState(() {
        final uniqueMaterials = <String, Map<String, dynamic>>{};
        for (var material in materialsWithUnits) {
          final name = material['materialName'] as String;
          if (!uniqueMaterials.containsKey(name)) {
            uniqueMaterials[name] = material;
          }
        }
        _materials = uniqueMaterials.values.toList();

        if (_selectedMaterial != null &&
            !_materials.any((m) => m['materialName'] == _selectedMaterial)) {
          _selectedMaterial = null;
          _selectedUnit = '';
        }
      });
    } catch (e) {
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

      final docId =
          '${movementId}_${_selectedVehicle}_${DateTime.now().millisecondsSinceEpoch}';

      String fromLocation = '';
      String toLocation = '';

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

      final selectedVehicle = _vehicles.firstWhere(
        (v) => v['id'] == _selectedVehicle,
        orElse: () => {'id': '', 'modelName': '', 'numberPlate': ''},
      );

      final movementData = {
        'movementId': movementId,
        'docId': docId,
        'vehicleId': _selectedVehicle ?? '',
        'vehicleModel': selectedVehicle['modelName'] ?? '',
        'vehicleNumberPlate': selectedVehicle['numberPlate'] ?? '',
        'date': dateFormatted,
        'timestamp': _selectedDate,
        'movementType': _movementType,
        'fromLocation': fromLocation,
        'toLocation': toLocation,
        'driverName': _selectedDriver ?? '',
        'startTime': _startTimeController.text.trim(),
        'endTime': _endTimeController.text.trim(),
        'materialType': _selectedMaterial ?? '',
        'materialUnit': _selectedUnit,
        'quantity': _quantityController.text.trim(),
        'quantityValue': double.tryParse(_quantityController.text.trim()) ?? 0,
        'distanceKm': _distanceController.text.trim(),
        'distanceValue': double.tryParse(_distanceController.text.trim()) ?? 0,
        'remarks': _remarksController.text.trim(),
        'createdAt': timestamp,
        'updatedAt': timestamp,
        'status': 'Active',
      };

      await FirestoreService.getCollection(
        'vehicleMovements',
      ).doc(docId).set(movementData);

      _showSuccessSnackBar('Vehicle movement logged successfully!');
      _resetForm();
    } catch (e) {
      _showErrorSnackBar('Failed to save movement: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
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
    if (!mounted) return;
    DialogUtils.showSuccessDialog(context, message: message);
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
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
    bool isMobile = MediaQuery.of(context).size.width < 600;

    if (_isLoading) {
      return GlassScaffold(
        title: 'Vehicle Movement Log',
        onBack: () => Navigator.pop(context),
        body: SafeArea(
          bottom: true,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMobile ? double.infinity : 600,
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading data...'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final primaryColor = Theme.of(context).colorScheme.primary;
    final darkCardBg = AppTheme.getDarkAccent(primaryColor);

    return GlassScaffold(
      title: 'Vehicle Movement Log',
      onBack: () => Navigator.pop(context),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Center(
            child: Container(
              width: 38,
              height: 38,
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
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                onPressed: _loadInitialData,
                tooltip: 'Reload Data',
              ),
            ),
          ),
        ),
      ],
      body: SafeArea(
        bottom: true,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 600,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Information Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.only(bottom: 16),
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
                          const Text(
                            'Basic Information',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Select Vehicle *',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
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
                            child: DropdownButtonFormField<String>(
                              value: _selectedVehicle,
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              decoration: InputDecoration(
                                hintText: 'Select Vehicle',
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                prefixIcon: const Icon(
                                  Icons.local_shipping_rounded,
                                  color: Color(0xFF0A183D),
                                ),
                              ),
                              style: const TextStyle(
                                color: Color(0xFF0A183D),
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                              items: _vehicles
                                  .map<DropdownMenuItem<String>>(
                                    (vehicle) => DropdownMenuItem<String>(
                                      value: vehicle['id'],
                                      child: Text(
                                        vehicle['modelName'] ?? '',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14.5,
                                          color: Color(0xFF0A183D),
                                        ),
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
                              validator: (value) => value == null
                                  ? 'Please select a vehicle'
                                  : null,
                              isExpanded: true,
                            ),
                          ),
                          if (_vehicles.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 6.0, left: 4.0),
                              child: Text(
                                'No vehicles available',
                                style: TextStyle(
                                  color: Color(0xFFF87171),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          const SizedBox(height: 14),
                          // Selected Vehicle Info
                          if (_selectedVehicle != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_rounded,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Selected Vehicle:',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFFCBD5E1),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _vehicles.firstWhere(
                                            (v) =>
                                                v['id'] == _selectedVehicle,
                                            orElse: () => {
                                              'id': '',
                                              'modelName': '',
                                            },
                                          )['modelName'],
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          // Date Selection
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Date: ${DateFormat('MMM dd, yyyy').format(_selectedDate)}',
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () => _selectDate(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: const Color(0xFF0A183D),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: const Text(
                                    'Change Date',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Movement Type Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.only(bottom: 16),
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
                          const Text(
                            'Movement Type',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 14),
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
                            child: DropdownButtonFormField<String>(
                              value: _movementType,
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              decoration: InputDecoration(
                                hintText: 'Select Movement Type',
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                prefixIcon: const Icon(
                                  Icons.swap_horiz_rounded,
                                  color: Color(0xFF0A183D),
                                ),
                              ),
                              style: const TextStyle(
                                color: Color(0xFF0A183D),
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                              items: [
                                'Company → Site',
                                'Site → Site',
                                'Site → Company',
                              ]
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
                          ),
                        ],
                      ),
                    ),

                    // Locations Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.only(bottom: 16),
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
                          const Text(
                            'Locations',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // From Location
                          if (_movementType != 'Company → Site')
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'From Site *',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
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
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedFromSite,
                                    dropdownColor: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    decoration: InputDecoration(
                                      hintText: 'From Site',
                                      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.location_on_rounded,
                                        color: Color(0xFF0A183D),
                                      ),
                                    ),
                                    style: const TextStyle(
                                      color: Color(0xFF0A183D),
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
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
                                ),
                                if (_siteNames.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 6.0, left: 4.0),
                                    child: Text(
                                      'No sites available',
                                      style: TextStyle(
                                        color: Color(0xFFF87171),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 14),
                              ],
                            ),

                          // To Location
                          if (_movementType != 'Site → Company') ...[
                            const Text(
                              'To Site *',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
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
                              child: DropdownButtonFormField<String>(
                                value: _selectedToSite,
                                dropdownColor: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                decoration: InputDecoration(
                                  hintText: 'To Site',
                                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.location_on_rounded,
                                    color: Color(0xFF0A183D),
                                  ),
                                ),
                                style: const TextStyle(
                                  color: Color(0xFF0A183D),
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
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
                            ),
                            if (_siteNames.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 6.0, left: 4.0),
                                child: Text(
                                  'No sites available',
                                  style: TextStyle(
                                    color: Color(0xFFF87171),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),

                    // Driver & Material Information Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.only(bottom: 16),
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
                          const Text(
                            'Driver & Material',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Select Driver *',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
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
                            child: DropdownButtonFormField<String>(
                              value: _selectedDriver,
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              decoration: InputDecoration(
                                hintText: 'Select Driver',
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                prefixIcon: const Icon(
                                  Icons.person_rounded,
                                  color: Color(0xFF0A183D),
                                ),
                              ),
                              style: const TextStyle(
                                color: Color(0xFF0A183D),
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
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
                              validator: (value) => value == null
                                  ? 'Please select a driver'
                                  : null,
                            ),
                          ),
                          if (_driverNames.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 6.0, left: 4.0),
                              child: Text(
                                'No drivers available',
                                style: TextStyle(
                                  color: Color(0xFFF87171),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          const SizedBox(height: 14),
                          // Material Information
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Material Type *',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
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
                                      child: DropdownButtonFormField<String>(
                                        value: _selectedMaterial,
                                        dropdownColor: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        decoration: InputDecoration(
                                          hintText: 'Material Type',
                                          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            borderSide: BorderSide.none,
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                          prefixIcon: const Icon(
                                            Icons.inventory_2_rounded,
                                            color: Color(0xFF0A183D),
                                          ),
                                        ),
                                        style: const TextStyle(
                                          color: Color(0xFF0A183D),
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        items: _materials
                                            .map<DropdownMenuItem<String>>(
                                              (material) =>
                                                  DropdownMenuItem<String>(
                                                    value:
                                                        material['materialName']
                                                            as String? ??
                                                        '',
                                                    child: Text(
                                                      material['materialName']
                                                              as String? ??
                                                          '',
                                                      overflow: TextOverflow.ellipsis,
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
                                    if (_materials.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 6.0, left: 4.0),
                                        child: Text(
                                          'No materials available',
                                          style: TextStyle(
                                            color: Color(0xFFF87171),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Quantity *',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
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
                                        controller: _quantityController,
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(
                                          color: Color(0xFF0A183D),
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Qty',
                                          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            borderSide: BorderSide.none,
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 14,
                                          ),
                                          prefixIcon: const Icon(
                                            Icons.scale_rounded,
                                            color: Color(0xFF0A183D),
                                          ),
                                          suffixText: _selectedUnit.isNotEmpty
                                              ? _selectedUnit
                                              : null,
                                          suffixStyle: const TextStyle(
                                            color: Color(0xFF0A183D),
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        validator: (value) =>
                                            value == null || value.isEmpty
                                            ? 'Enter qty'
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (_selectedUnit.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                'Unit: $_selectedUnit',
                                style: const TextStyle(
                                  color: Color(0xFF22C55E),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Time & Distance Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.only(bottom: 16),
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
                          const Text(
                            'Time & Distance',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Start Time *',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
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
                                        controller: _startTimeController,
                                        readOnly: true,
                                        style: const TextStyle(
                                          color: Color(0xFF0A183D),
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'hh:mm a',
                                          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            borderSide: BorderSide.none,
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 14,
                                          ),
                                          prefixIcon: const Icon(
                                            Icons.access_time_rounded,
                                            color: Color(0xFF0A183D),
                                          ),
                                        ),
                                        onTap: () => _selectTime(
                                          context,
                                          _startTimeController,
                                        ),
                                        validator: (value) =>
                                            value == null || value.isEmpty
                                            ? 'Enter start time'
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'End Time *',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
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
                                        controller: _endTimeController,
                                        readOnly: true,
                                        style: const TextStyle(
                                          color: Color(0xFF0A183D),
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'hh:mm a',
                                          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            borderSide: BorderSide.none,
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 14,
                                          ),
                                          prefixIcon: const Icon(
                                            Icons.access_time_rounded,
                                            color: Color(0xFF0A183D),
                                          ),
                                        ),
                                        onTap: () => _selectTime(
                                          context,
                                          _endTimeController,
                                        ),
                                        validator: (value) =>
                                            value == null || value.isEmpty
                                            ? 'Enter end time'
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Distance (km) *',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
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
                              controller: _distanceController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                color: Color(0xFF0A183D),
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Distance in km',
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                prefixIcon: const Icon(
                                  Icons.speed_rounded,
                                  color: Color(0xFF0A183D),
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? 'Enter distance'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Remarks Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.only(bottom: 16),
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
                          const Text(
                            'Additional Information',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Remarks',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
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
                              controller: _remarksController,
                              maxLines: 3,
                              style: const TextStyle(
                                color: Color(0xFF0A183D),
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter remarks...',
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.all(16),
                                prefixIcon: const Icon(
                                  Icons.note_alt_rounded,
                                  color: Color(0xFF0A183D),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Submit Button
                    Container(
                      padding: const EdgeInsets.all(16),
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
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: _isSubmitting
                            ? const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : ElevatedButton.icon(
                                onPressed: _submitForm,
                                icon: const Icon(Icons.save_rounded, size: 20),
                                label: const Text(
                                  'Save Movement Log',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: const Color(0xFF0A183D),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 6,
                                  shadowColor: primaryColor.withValues(alpha: 0.4),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
