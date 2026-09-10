import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ebricks/services/firestore_service.dart';
import 'package:ebricks/services/material_inventory_service.dart';
import 'package:ebricks/utils/app_theme.dart';
import 'package:ebricks/utils/dialog_utils.dart';
import 'package:ebricks/utils/responsive.dart';

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

  // Other material specific controllers
  final TextEditingController _otherMaterialNameController = TextEditingController();
  final TextEditingController _otherQuantityController = TextEditingController();
  final TextEditingController _otherUnitController = TextEditingController();
  final TextEditingController _otherShopNameController = TextEditingController();
  final TextEditingController _otherVendorController = TextEditingController();

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
  int? _materialAvailableCount;
  bool _isLoading = true;
  bool _isSubmitting = false;

  // Real-time vehicle assignment tracking
  List<Map<String, dynamic>> _driversList = [];
  String? _assignedDriverName;
  String? _assignedDriverId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _vehiclesSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _driversSubscription;

  @override
  void initState() {
    super.initState();
    _setCurrentTime();
    _loadInitialData();
  }

  @override
  void dispose() {
    _vehiclesSubscription?.cancel();
    _driversSubscription?.cancel();
    _fromLocationController.dispose();
    _toLocationController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _quantityController.dispose();
    _distanceController.dispose();
    _remarksController.dispose();
    _otherMaterialNameController.dispose();
    _otherQuantityController.dispose();
    _otherUnitController.dispose();
    _otherShopNameController.dispose();
    _otherVendorController.dispose();
    super.dispose();
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
      _listenToRealtimeUpdates();
    } catch (e) {
      _showErrorSnackBar('Error loading initial data: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _listenToRealtimeUpdates() {
    _vehiclesSubscription = FirestoreService.getCollection('vehicleDetails')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      final vehicles = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': data['id'] as String? ?? doc.id,
          'modelName': data['modelName'] as String? ?? '',
          'numberPlate': data['numberPlate'] as String? ?? '',
          'isAssigned': data['isAssigned'] as bool? ?? false,
          'assignedDriverId': data['assignedDriverId'] as String?,
          'assignedDriverName': data['assignedDriverName'] as String?,
        };
      }).toList();

      setState(() {
        _vehicles = vehicles;
        if (_selectedVehicle != null) {
          _updateAssignedDriverForSelectedVehicle();
        }
      });
    }, onError: (e) {
      debugPrint('Error listening to vehicleDetails: $e');
    });

    _driversSubscription = FirestoreService.getCollection('drivers')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      final names = <String>[];
      final drivers = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final name = data['driverName'] as String? ?? '';
        if (name.isNotEmpty) {
          names.add(name);
          drivers.add({
            'driverId': data['driverId'] ?? doc.id,
            'driverName': name,
            'status': data['status'] ?? 'Active',
            'assignedVehicleId': data['assignedVehicleId'] as String?,
          });
        }
      }
      setState(() {
        _driverNames = names;
        _driversList = drivers;
        if (_selectedVehicle != null) {
          _updateAssignedDriverForSelectedVehicle();
        }
      });
    }, onError: (e) {
      debugPrint('Error listening to drivers: $e');
    });
  }

  void _updateAssignedDriverForSelectedVehicle() {
    if (_selectedVehicle == null || _selectedVehicle!.isEmpty) {
      _assignedDriverName = null;
      _assignedDriverId = null;
      _selectedDriver = null;
      return;
    }

    // 1. Check in vehicles collection
    final vehicle = _vehicles.firstWhere(
      (v) => v['id'] == _selectedVehicle,
      orElse: () => {},
    );

    String? foundDriverName;
    String? foundDriverId;

    if (vehicle.isNotEmpty) {
      final isAssigned = vehicle['isAssigned'] as bool? ?? false;
      final assignedName = vehicle['assignedDriverName'] as String?;
      final assignedId = vehicle['assignedDriverId'] as String?;

      if (isAssigned && assignedName != null && assignedName.trim().isNotEmpty) {
        foundDriverName = assignedName.trim();
        foundDriverId = assignedId;
      }
    }

    // 2. Fallback check: look up in drivers collection if not populated on vehicle doc
    if (foundDriverName == null && _driversList.isNotEmpty) {
      final driver = _driversList.firstWhere(
        (d) =>
            d['assignedVehicleId'] == _selectedVehicle &&
            (d['status'] ?? 'Active') == 'Active',
        orElse: () => {},
      );
      if (driver.isNotEmpty) {
        foundDriverName = driver['driverName'] as String?;
        foundDriverId = driver['driverId'] as String?;
      }
    }

    _assignedDriverName = foundDriverName;
    _assignedDriverId = foundDriverId;

    if (foundDriverName != null && foundDriverName.isNotEmpty) {
      _selectedDriver = foundDriverName;
      if (!_driverNames.contains(foundDriverName)) {
        _driverNames.add(foundDriverName);
      }
    }
  }

  Future<void> _loadDrivers() async {
    try {
      final snapshot = await FirestoreService.getCollection('drivers').get();
      final names = <String>[];
      final drivers = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final name = data['driverName'] as String? ?? '';
        if (name.isNotEmpty) {
          names.add(name);
          drivers.add({
            'driverId': data['driverId'] ?? doc.id,
            'driverName': name,
            'status': data['status'] ?? 'Active',
            'assignedVehicleId': data['assignedVehicleId'] as String?,
          });
        }
      }
      setState(() {
        _driverNames = names;
        _driversList = drivers;
      });
    } catch (e) {
      debugPrint('Error loading drivers: $e');
    }
  }

  Future<void> _loadSites() async {
    try {
      final snapshot = await FirestoreService.getCollection('projects').get();
      final names = snapshot.docs
          .map((doc) => doc['siteName'] as String? ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
      setState(() {
        _siteNames = names;
      });
    } catch (e) {
      debugPrint('Error loading sites: $e');
    }
  }

  Future<void> _loadVehicles() async {
    try {
      final snapshot =
          await FirestoreService.getCollection('vehicleDetails').get();
      final vehicles = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': data['id'] as String? ?? doc.id,
          'modelName': data['modelName'] as String? ?? '',
          'numberPlate': data['numberPlate'] as String? ?? '',
          'isAssigned': data['isAssigned'] as bool? ?? false,
          'assignedDriverId': data['assignedDriverId'] as String?,
          'assignedDriverName': data['assignedDriverName'] as String?,
        };
      }).toList();
      setState(() {
        _vehicles = vehicles;
      });
    } catch (e) {
      debugPrint('Error loading vehicles: $e');
    }
  }

  Future<void> _loadMaterials() async {
    try {
      final items = await MaterialInventoryService.fetchAllMaterialsInventory();
      final materials = items.map((item) {
        return {
          'materialName': item.displayName.isNotEmpty ? item.displayName : item.materialName,
          'unit': item.unit,
        };
      }).toList();

      setState(() {
        _materials = materials;
      });
    } catch (e) {
      debugPrint('Error loading materials: $e');
    }
  }

  Future<String> _getNextMovementId() async {
    try {
      final snapshot = await FirestoreService.getCollection('vehicleMovements')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return 'VM001';

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
      _materialAvailableCount = null;

      if (materialName != null && materialName != 'Other' && materialName.isNotEmpty) {
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
    if (materialName != null && materialName != 'Other' && materialName.isNotEmpty) {
      _fetchMaterialAvailableCount(materialName);
    }
  }

  Future<void> _fetchMaterialAvailableCount(String? materialName) async {
    if (materialName == null || materialName.isEmpty) {
      setState(() => _materialAvailableCount = null);
      return;
    }
    try {
      final item = await MaterialInventoryService.fetchMaterialInventory(materialName);
      if (mounted) {
        setState(() => _materialAvailableCount = item?.companyAvailableCount ?? 0);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _materialAvailableCount = 0);
      }
    }
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
      final docId = '${movementId}_${_selectedVehicle}_${DateTime.now().millisecondsSinceEpoch}';

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

      final bool isOther = _selectedMaterial == 'Other';
      final otherMatName = _otherMaterialNameController.text.trim();
      final otherShop = _otherShopNameController.text.trim();
      final otherVendor = _otherVendorController.text.trim();
      final otherUnit = _otherUnitController.text.trim();
      final otherQty = _otherQuantityController.text.trim();

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
        'assignedDriverId': _assignedDriverId ?? '',
        'startTime': _startTimeController.text.trim(),
        'endTime': _endTimeController.text.trim(),
        'materialType': isOther ? (otherMatName.isNotEmpty ? otherMatName : 'Other') : (_selectedMaterial ?? ''),
        'isOtherMaterial': isOther,
        'otherMaterialName': isOther ? otherMatName : null,
        'otherShopName': isOther ? otherShop : null,
        'otherVendor': isOther ? otherVendor : null,
        'materialUnit': isOther ? otherUnit : _selectedUnit,
        'quantity': isOther ? otherQty : _quantityController.text.trim(),
        'quantityValue': double.tryParse(isOther ? otherQty : _quantityController.text.trim()) ?? 0,
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
      _assignedDriverName = null;
      _assignedDriverId = null;
    });
    _setCurrentTime();
    _startTimeController.clear();
    _endTimeController.clear();
    _quantityController.clear();
    _distanceController.clear();
    _remarksController.clear();
    _otherMaterialNameController.clear();
    _otherQuantityController.clear();
    _otherUnitController.clear();
    _otherShopNameController.clear();
    _otherVendorController.clear();
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
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final primaryColor = Theme.of(context).primaryColor;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          title: const Text('Vehicle Fleet Log', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: darkAccent,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Vehicle Fleet Log',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
            onPressed: _loadInitialData,
            tooltip: 'Reload Data',
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 650),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBasicInfoSection(primaryColor),
                    const SizedBox(height: 16),
                    _buildMovementTypeSection(primaryColor),
                    const SizedBox(height: 16),
                    _buildDriverAndMaterialSection(primaryColor),
                    const SizedBox(height: 16),
                    _buildTimeAndDistanceSection(primaryColor),
                    const SizedBox(height: 16),
                    _buildRemarksSection(primaryColor),
                    const SizedBox(height: 20),
                    _buildSubmitButton(primaryColor),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection(Color primaryColor) {
    return _buildSectionCard(
      title: 'Basic Information',
      icon: Icons.directions_car_rounded,
      primaryColor: primaryColor,
      children: [
        _buildCustomField(
          label: 'Select Vehicle *',
          child: DropdownButtonFormField<String>(
            key: ValueKey('vehicle_$_selectedVehicle'),
            initialValue: _selectedVehicle,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(14),
            decoration: InputDecoration(
              hintText: 'Choose vehicle',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              prefixIcon: const Icon(Icons.local_shipping_rounded, color: Color(0xFF64748B), size: 20),
              suffixIcon: _selectedVehicle != null
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                      tooltip: 'Clear vehicle selection',
                      onPressed: () {
                        setState(() {
                          _selectedVehicle = null;
                          _updateAssignedDriverForSelectedVehicle();
                        });
                      },
                    )
                  : null,
            ),
            style: const TextStyle(color: Color(0xFF0A183D), fontSize: 14.5, fontWeight: FontWeight.w700),
            items: _vehicles.map<DropdownMenuItem<String>>((v) {
              final model = v['modelName'] as String? ?? '';
              final plate = v['numberPlate'] as String? ?? '';
              final id = v['id'] as String;
              return DropdownMenuItem<String>(
                value: id,
                child: Text(
                  '$model ($plate) - $id',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: _vehicles.isEmpty
                ? null
                : (val) {
                    setState(() {
                      _selectedVehicle = val;
                      _updateAssignedDriverForSelectedVehicle();
                    });
                  },
            validator: (val) => val == null ? 'Please select a vehicle' : null,
            isExpanded: true,
          ),
        ),
        if (_selectedVehicle != null) ...[
          _buildAssignedDriverBanner(primaryColor),
        ],
        const SizedBox(height: 12),
        _buildCustomField(
          label: 'Log Date *',
          child: InkWell(
            onTap: () => _selectDate(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, color: primaryColor, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    DateFormat('EEEE, MMM dd, yyyy').format(_selectedDate),
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF0A183D)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssignedDriverBanner(Color primaryColor) {
    final bool hasDriver = _assignedDriverName != null && _assignedDriverName!.isNotEmpty;

    if (hasDriver) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CURRENTLY ASSIGNED DRIVER',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF047857),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_assignedDriverName${_assignedDriverId != null && _assignedDriverId!.isNotEmpty ? " ($_assignedDriverId)" : ""}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Assigned',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF047857),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFF59E0B),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_off_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VEHICLE ASSIGNMENT STATUS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFB45309),
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'No Driver Assigned',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Unassigned',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFB45309),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildMovementTypeSection(Color primaryColor) {
    return _buildSectionCard(
      title: 'Movement Route',
      icon: Icons.swap_horiz_rounded,
      primaryColor: primaryColor,
      children: [
        _buildCustomField(
          label: 'Movement Type *',
          child: DropdownButtonFormField<String>(
            initialValue: _movementType,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(14),
            isExpanded: true,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              prefixIcon: Icon(Icons.alt_route_rounded, color: Color(0xFF64748B), size: 20),
            ),
            style: const TextStyle(color: Color(0xFF0A183D), fontSize: 14.5, fontWeight: FontWeight.w700),
            items: ['Company → Site', 'Site → Site', 'Site → Company']
                .map((type) => DropdownMenuItem(value: type, child: Text(type, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (value) {
              setState(() => _movementType = value!);
              _updateLocationFields();
            },
          ),
        ),
        if (_movementType != 'Company → Site') ...[
          const SizedBox(height: 12),
          _buildCustomField(
            label: 'From Site *',
            child: DropdownButtonFormField<String>(
              initialValue: _selectedFromSite,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(14),
              isExpanded: true,
              decoration: const InputDecoration(
                hintText: 'Select origin site',
                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                prefixIcon: Icon(Icons.location_on_rounded, color: Color(0xFF64748B), size: 20),
              ),
              style: const TextStyle(color: Color(0xFF0A183D), fontSize: 14.5, fontWeight: FontWeight.w700),
              items: _siteNames.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (val) => setState(() => _selectedFromSite = val),
              validator: (val) => (_movementType != 'Company → Site' && (val == null || val.isEmpty))
                  ? 'Please select origin site'
                  : null,
            ),
          ),
        ],
        if (_movementType != 'Site → Company') ...[
          const SizedBox(height: 12),
          _buildCustomField(
            label: 'To Site *',
            child: DropdownButtonFormField<String>(
              initialValue: _selectedToSite,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(14),
              isExpanded: true,
              decoration: const InputDecoration(
                hintText: 'Select destination site',
                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                prefixIcon: Icon(Icons.place_rounded, color: Color(0xFF64748B), size: 20),
              ),
              style: const TextStyle(color: Color(0xFF0A183D), fontSize: 14.5, fontWeight: FontWeight.w700),
              items: _siteNames.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (val) => setState(() => _selectedToSite = val),
              validator: (val) => (_movementType != 'Site → Company' && (val == null || val.isEmpty))
                  ? 'Please select destination site'
                  : null,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDriverAndMaterialSection(Color primaryColor) {
    final allDriverOptions = <String>{..._driverNames};
    if (_selectedDriver != null && _selectedDriver!.isNotEmpty) {
      allDriverOptions.add(_selectedDriver!);
    }

    return _buildSectionCard(
      title: 'Driver & Material',
      icon: Icons.person_pin_rounded,
      primaryColor: primaryColor,
      children: [
        _buildCustomField(
          label: 'Select Driver *',
          child: DropdownButtonFormField<String>(
            key: ValueKey('driver_${_selectedDriver}_$_selectedVehicle'),
            initialValue: _selectedDriver,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(14),
            isExpanded: true,
            decoration: InputDecoration(
              hintText: 'Assign driver for trip',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFF64748B), size: 20),
              suffixIcon: (_assignedDriverName != null && _selectedDriver == _assignedDriverName)
                  ? Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: const Tooltip(
                        message: 'Assigned Driver from Configuration',
                        child: Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 18),
                      ),
                    )
                  : null,
            ),
            style: const TextStyle(color: Color(0xFF0A183D), fontSize: 14.5, fontWeight: FontWeight.w700),
            items: allDriverOptions.map((d) {
              final isVehicleDriver = d == _assignedDriverName;
              return DropdownMenuItem(
                value: d,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        d,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: isVehicleDriver ? FontWeight.w800 : FontWeight.w700,
                          color: isVehicleDriver ? const Color(0xFF059669) : const Color(0xFF0A183D),
                        ),
                      ),
                    ),
                    if (isVehicleDriver)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: const Text(
                          'Assigned',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (val) => setState(() => _selectedDriver = val),
            validator: (val) => (val == null || val.isEmpty) ? 'Please select driver' : null,
          ),
        ),
        if (_assignedDriverName != null && _assignedDriverName!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF059669)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Auto-assigned to $_assignedDriverName from Driver Configuration',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF059669),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ] else if (_selectedVehicle != null) ...[
          const SizedBox(height: 4),
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFFB45309)),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  'No Driver Assigned to this vehicle. Please select a driver manually.',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB45309),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        _buildCustomField(
          label: 'Material Type *',
          child: DropdownButtonFormField<String>(
            key: ValueKey('material_$_selectedMaterial'),
            initialValue: _selectedMaterial,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(14),
            isExpanded: true,
            decoration: const InputDecoration(
              hintText: 'Select material',
              hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              prefixIcon: Icon(Icons.inventory_2_rounded, color: Color(0xFF64748B), size: 18),
            ),
            style: const TextStyle(color: Color(0xFF0A183D), fontSize: 14, fontWeight: FontWeight.w700),
            items: [
              ..._materials.map((m) {
                final name = m['materialName'] as String;
                return DropdownMenuItem(value: name, child: Text(name, overflow: TextOverflow.ellipsis));
              }),
              const DropdownMenuItem(
                value: 'Other',
                child: Row(
                  children: [
                    Icon(Icons.category_rounded, size: 16, color: Color(0xFF2563EB)),
                    SizedBox(width: 8),
                    Text(
                      'Other (Custom Material)',
                      style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                    ),
                  ],
                ),
              ),
            ],
            onChanged: _onMaterialSelected,
            validator: (val) => (val == null || val.isEmpty) ? 'Select material' : null,
          ),
        ),
        if (_selectedMaterial == 'Other') ...[
          _buildOtherMaterialSection(primaryColor),
        ] else ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildCustomField(
                  label: 'Quantity *',
                  child: TextFormField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Color(0xFF0A183D), fontSize: 14.5, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: 'Enter quantity',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      suffixText: _selectedUnit.isNotEmpty ? _selectedUnit : null,
                      suffixStyle: TextStyle(color: primaryColor, fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                    validator: (val) => (_selectedMaterial != 'Other' && (val == null || val.isEmpty)) ? 'Enter qty' : null,
                  ),
                ),
              ),
            ],
          ),
          if (_selectedMaterial != null && _selectedMaterial != 'Other') ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 14,
                  color: (_materialAvailableCount ?? 0) > 0 ? const Color(0xFF059669) : Colors.redAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  'Available Stock: ${_materialAvailableCount ?? "..."} ${_selectedUnit.isNotEmpty ? _selectedUnit : ""}',
                  style: TextStyle(
                    color: (_materialAvailableCount ?? 0) > 0 ? const Color(0xFF059669) : Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildOtherMaterialSection(Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E40AF).withValues(alpha: 0.04),
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.category_rounded, size: 16, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 8),
              const Text(
                'Other Material Details',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCustomField(
            label: 'Material Name *',
            child: TextFormField(
              controller: _otherMaterialNameController,
              style: const TextStyle(color: Color(0xFF0A183D), fontSize: 14, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                hintText: 'Enter material name',
                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                prefixIcon: Icon(Icons.drive_file_rename_outline_rounded, color: Color(0xFF64748B), size: 18),
              ),
              validator: (val) => (_selectedMaterial == 'Other' && (val == null || val.trim().isEmpty))
                  ? 'Please enter material name'
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildCustomField(
                  label: 'Quantity *',
                  child: TextFormField(
                    controller: _otherQuantityController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Color(0xFF0A183D), fontSize: 14, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(
                      hintText: 'Enter quantity',
                      hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      prefixIcon: Icon(Icons.numbers_rounded, color: Color(0xFF64748B), size: 18),
                    ),
                    validator: (val) => (_selectedMaterial == 'Other' && (val == null || val.trim().isEmpty))
                        ? 'Please enter quantity'
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: _buildCustomField(
                  label: 'Unit',
                  child: TextFormField(
                    controller: _otherUnitController,
                    style: const TextStyle(color: Color(0xFF0A183D), fontSize: 14, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(
                      hintText: 'Kg/Nos',
                      hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCustomField(
            label: 'Shop Name (Optional)',
            child: TextFormField(
              controller: _otherShopNameController,
              style: const TextStyle(color: Color(0xFF0A183D), fontSize: 14, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                hintText: 'Enter shop name (optional)',
                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                prefixIcon: Icon(Icons.storefront_rounded, color: Color(0xFF64748B), size: 18),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildCustomField(
            label: 'Vendor (Optional)',
            child: TextFormField(
              controller: _otherVendorController,
              style: const TextStyle(color: Color(0xFF0A183D), fontSize: 14, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                hintText: 'Enter vendor name (optional)',
                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                prefixIcon: Icon(Icons.business_rounded, color: Color(0xFF64748B), size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeAndDistanceSection(Color primaryColor) {
    return _buildSectionCard(
      title: 'Time & Distance',
      icon: Icons.timer_rounded,
      primaryColor: primaryColor,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildCustomField(
                label: 'Start Time *',
                child: TextFormField(
                  controller: _startTimeController,
                  readOnly: true,
                  onTap: () => _selectTime(context, _startTimeController),
                  style: const TextStyle(color: Color(0xFF0A183D), fontSize: 14.5, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    hintText: 'hh:mm a',
                    hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    prefixIcon: Icon(Icons.access_time_rounded, color: Color(0xFF64748B), size: 20),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Start time' : null,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildCustomField(
                label: 'End Time *',
                child: TextFormField(
                  controller: _endTimeController,
                  readOnly: true,
                  onTap: () => _selectTime(context, _endTimeController),
                  style: const TextStyle(color: Color(0xFF0A183D), fontSize: 14.5, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    hintText: 'hh:mm a',
                    hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    prefixIcon: Icon(Icons.access_time_filled_rounded, color: Color(0xFF64748B), size: 20),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'End time' : null,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildCustomField(
          label: 'Distance (km) *',
          child: TextFormField(
            controller: _distanceController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Color(0xFF0A183D), fontSize: 14.5, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              hintText: 'Distance in kilometers',
              hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              prefixIcon: Icon(Icons.speed_rounded, color: Color(0xFF64748B), size: 20),
            ),
            validator: (val) => val == null || val.isEmpty ? 'Enter distance' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildRemarksSection(Color primaryColor) {
    return _buildSectionCard(
      title: 'Additional Information',
      icon: Icons.note_alt_rounded,
      primaryColor: primaryColor,
      children: [
        _buildCustomField(
          label: 'Remarks / Notes',
          child: TextFormField(
            controller: _remarksController,
            maxLines: 2,
            style: const TextStyle(color: Color(0xFF0A183D), fontSize: 14.5, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              hintText: 'Any extra trip notes or remarks...',
              hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color primaryColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildCustomField({required String label, required Widget child}) {
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildSubmitButton(Color primaryColor) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
        ),
        icon: const Icon(Icons.save_rounded, size: 20),
        label: _isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text(
                'SAVE MOVEMENT LOG',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.5),
              ),
      ),
    );
  }
}
