import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:ebricks/services/firestore_service.dart';
import 'package:ebricks/services/driver_vehicle_service.dart';
import 'package:ebricks/utils/app_theme.dart';
import 'package:ebricks/utils/dialog_utils.dart';
import 'package:ebricks/utils/responsive.dart';

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
  final TextEditingController _searchController = TextEditingController();

  String _driverStatus = 'Active';
  String _currentDriverId = '';
  bool _isEditing = false;
  bool _isSaving = false;
  String _searchQuery = '';

  // Vehicle assignment fields
  String? _selectedVehicleId;
  String? _selectedVehicleModel;
  String? _selectedVehiclePlate;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _driverNameController.dispose();
    _driverPhoneController.dispose();
    _driverAddressController.dispose();
    _driverLicenseController.dispose();
    _experienceController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _saveDriver() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final driverId =
          _isEditing ? _currentDriverId : await DriverVehicleService.getNextDriverId();

      await DriverVehicleService.saveDriverWithAssignment(
        driverId: driverId,
        driverName: _driverNameController.text.trim(),
        driverPhone: _driverPhoneController.text.trim(),
        driverAddress: _driverAddressController.text.trim(),
        driverLicense: _driverLicenseController.text.trim(),
        experience: _experienceController.text.trim(),
        status: _driverStatus,
        newVehicleId: _selectedVehicleId,
        newVehicleModel: _selectedVehicleModel,
        newVehiclePlate: _selectedVehiclePlate,
        isEditing: _isEditing,
      );

      if (mounted) {
        await DialogUtils.showSuccessDialog(
          context,
          message: 'Driver ${_isEditing ? 'updated' : 'saved'} successfully!',
        );
      }

      _resetForm();
      _tabController.animateTo(1);
    } on VehicleAssignmentException catch (e) {
      if (mounted) {
        await DialogUtils.showWarningDialog(
          context,
          message: e.message,
        );
      }
    } catch (e) {
      if (mounted) {
        await DialogUtils.showWarningDialog(
          context,
          message: 'Error saving driver: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _editDriver(DocumentSnapshot driver) {
    final data = driver.data() as Map<String, dynamic>;
    setState(() {
      _isEditing = true;
      _currentDriverId = data['driverId'] ?? driver.id;
      _driverNameController.text = data['driverName'] ?? '';
      _driverPhoneController.text = data['driverPhone'] ?? '';
      _driverAddressController.text = data['driverAddress'] ?? '';
      _driverLicenseController.text = data['driverLicense'] ?? '';
      _experienceController.text = data['experience'] ?? '';
      _driverStatus = data['status'] ?? 'Active';
      _selectedVehicleId = data['assignedVehicleId'] as String?;
      _selectedVehicleModel = data['assignedVehicleModel'] as String?;
      _selectedVehiclePlate = data['assignedVehiclePlate'] as String?;
    });
    _tabController.animateTo(0);
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _driverNameController.clear();
    _driverPhoneController.clear();
    _driverAddressController.clear();
    _driverLicenseController.clear();
    _experienceController.clear();
    setState(() {
      _isEditing = false;
      _currentDriverId = '';
      _driverStatus = 'Active';
      _selectedVehicleId = null;
      _selectedVehicleModel = null;
      _selectedVehiclePlate = null;
    });
  }

  Future<void> _deleteDriver(String driverId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Driver', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete driver $driverId?\nAny assigned vehicle will be released.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() => _isSaving = true);
      try {
        await DriverVehicleService.deleteDriver(driverId);
        if (mounted) {
          await DialogUtils.showSuccessDialog(
            context,
            message: 'Driver deleted and vehicle released successfully!',
          );
        }
      } catch (e) {
        if (mounted) {
          await DialogUtils.showWarningDialog(
            context,
            message: 'Error deleting driver: $e',
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final primaryColor = Theme.of(context).primaryColor;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Driver Configuration',
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
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 650),
            child: Column(
              children: [
                const SizedBox(height: 12),
                _buildPillTabBar(primaryColor),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildNewDriverTab(primaryColor),
                      _buildExistingDriversTab(primaryColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPillTabBar(Color primaryColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _tabController.animateTo(0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _tabController.index == 0 ? primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_add_rounded,
                      size: 16,
                      color: _tabController.index == 0 ? Colors.white : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isEditing ? 'EDIT DRIVER' : 'NEW DRIVER',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: _tabController.index == 0 ? Colors.white : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _tabController.animateTo(1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _tabController.index == 1 ? primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_rounded,
                      size: 16,
                      color: _tabController.index == 1 ? Colors.white : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'EXISTING DRIVERS',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewDriverTab(Color primaryColor) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
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
                        child: Icon(
                          _isEditing ? Icons.edit_rounded : Icons.person_add_rounded,
                          color: primaryColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _isEditing ? 'Edit Driver ($_currentDriverId)' : 'Register New Driver',
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Driver Name *'),
                      TextFormField(
                        controller: _driverNameController,
                        textAlignVertical: TextAlignVertical.center,
                        style: const TextStyle(
                          color: Color(0xFF0A183D),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _buildInputDecoration(
                          primaryColor: primaryColor,
                          icon: Icons.person_rounded,
                          hintText: 'Enter full name',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Enter driver name' : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Phone Number *'),
                      TextFormField(
                        controller: _driverPhoneController,
                        keyboardType: TextInputType.number,
                        textAlignVertical: TextAlignVertical.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        style: const TextStyle(
                          color: Color(0xFF0A183D),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _buildInputDecoration(
                          primaryColor: primaryColor,
                          icon: Icons.phone_rounded,
                          hintText: 'Enter 10-digit phone number',
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Enter phone number';
                          if (v.length != 10) return 'Phone number must be 10 digits';
                          return null;
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('License Number *'),
                      TextFormField(
                        controller: _driverLicenseController,
                        textAlignVertical: TextAlignVertical.center,
                        style: const TextStyle(
                          color: Color(0xFF0A183D),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _buildInputDecoration(
                          primaryColor: primaryColor,
                          icon: Icons.badge_rounded,
                          hintText: 'Enter driver license number',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Enter license number' : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Experience (years) *'),
                      TextFormField(
                        controller: _experienceController,
                        keyboardType: TextInputType.number,
                        textAlignVertical: TextAlignVertical.center,
                        style: const TextStyle(
                          color: Color(0xFF0A183D),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _buildInputDecoration(
                          primaryColor: primaryColor,
                          icon: Icons.workspace_premium_rounded,
                          hintText: 'Years of driving experience',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Enter experience' : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Address *'),
                      TextFormField(
                        controller: _driverAddressController,
                        minLines: 2,
                        maxLines: 4,
                        textAlignVertical: TextAlignVertical.top,
                        style: const TextStyle(
                          color: Color(0xFF0A183D),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _buildInputDecoration(
                          primaryColor: primaryColor,
                          icon: Icons.location_on_rounded,
                          hintText: 'Enter resident address',
                          isMultiLine: true,
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Enter address' : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildVehicleDropdown(primaryColor),
                  const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Status *'),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _driverStatus,
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        style: const TextStyle(
                          color: Color(0xFF0A183D),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _buildInputDecoration(
                          primaryColor: primaryColor,
                          icon: Icons.toggle_on_rounded,
                          hintText: 'Select Status',
                        ),
                        items: ['Active', 'Inactive'].map((e) {
                          final isAct = e == 'Active';
                          return DropdownMenuItem(
                            value: e,
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isAct ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                  ),
                                ),
                                Text(
                                  e,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isAct ? const Color(0xFF0F172A) : const Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() {
                            _driverStatus = val;
                            if (_driverStatus == 'Inactive') {
                              _selectedVehicleId = null;
                              _selectedVehicleModel = null;
                              _selectedVehiclePlate = null;
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  if (_driverStatus == 'Inactive') ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFFDC2626)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Inactive drivers cannot hold assigned vehicles. Any assigned vehicle is released automatically upon save.',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (_isEditing) ...[
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : _resetForm,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveDriver,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 1,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _isEditing ? 'UPDATE DRIVER' : 'SAVE DRIVER',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    final isRequired = label.contains('*');
    final cleanText = label.replaceAll('*', '').trim();
    return Padding(
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
    );
  }

  InputDecoration _buildInputDecoration({
    required Color primaryColor,
    required IconData icon,
    required String hintText,
    Widget? suffixIcon,
    bool isMultiLine = false,
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
        padding: EdgeInsets.only(
          left: 12,
          right: 8,
          top: isMultiLine ? 10 : 0,
          bottom: isMultiLine ? 10 : 0,
        ),
        child: Icon(icon, color: primaryColor, size: 18),
      ),
      prefixIconConstraints: BoxConstraints(
        minWidth: 38,
        minHeight: isMultiLine ? 24 : 38,
      ),
      suffixIcon: suffixIcon,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: isMultiLine ? 12 : 12.5,
      ),
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
      errorStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Color(0xFFEF4444),
      ),
    );
  }

  Widget _buildVehicleDropdown(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Assigned Vehicle (Optional)'),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: DriverVehicleService.streamAvailableVehicles(
            currentDriverId: _isEditing ? _currentDriverId : null,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Loading available vehicles...',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                    ),
                  ],
                ),
              );
            }

            final availableVehicles = snapshot.data ?? [];

            final bool hasMatch = _selectedVehicleId == null ||
                availableVehicles.any((v) => v['id'] == _selectedVehicleId);

            return DropdownButtonFormField<String?>(
              key: ValueKey('vehicle_${_selectedVehicleId}_$_isEditing'),
              isExpanded: true,
              initialValue: hasMatch ? _selectedVehicleId : null,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              style: const TextStyle(
                color: Color(0xFF0A183D),
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
              decoration: _buildInputDecoration(
                primaryColor: primaryColor,
                icon: Icons.directions_car_rounded,
                hintText: 'Select vehicle (Optional)',
                suffixIcon: _selectedVehicleId != null
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                        tooltip: 'Clear Vehicle Assignment',
                        onPressed: () {
                          setState(() {
                            _selectedVehicleId = null;
                            _selectedVehicleModel = null;
                            _selectedVehiclePlate = null;
                          });
                        },
                      )
                    : null,
              ),
              hint: const Text(
                'Select vehicle (Optional)',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    'No Vehicle Assigned (Unassigned)',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                ...availableVehicles.map((vehicle) {
                  final vId = vehicle['id'] as String;
                  final model = vehicle['modelName'] as String;
                  final plate = vehicle['numberPlate'] as String;
                  final isCurrent = vehicle['isCurrentDriverAssigned'] == true;

                  return DropdownMenuItem<String?>(
                    value: vId,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$model ($plate)',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isCurrent ? primaryColor : const Color(0xFF0A183D),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? primaryColor.withValues(alpha: 0.12)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isCurrent ? '$vId (Current)' : vId,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: isCurrent ? primaryColor : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              onChanged: _driverStatus == 'Inactive'
                  ? null
                  : (val) {
                      setState(() {
                        _selectedVehicleId = val;
                        if (val != null) {
                          final chosen = availableVehicles.firstWhere(
                            (v) => v['id'] == val,
                            orElse: () => {'modelName': '', 'numberPlate': ''},
                          );
                          _selectedVehicleModel = chosen['modelName'] as String?;
                          _selectedVehiclePlate = chosen['numberPlate'] as String?;
                        } else {
                          _selectedVehicleModel = null;
                          _selectedVehiclePlate = null;
                        }
                      });
                    },
            );
          },
        ),
      ],
    );
  }

  Widget _buildExistingDriversTab(Color primaryColor) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(color: Color(0xFF0A183D), fontSize: 13.5, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search driver by name, phone, license, or vehicle...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, fontWeight: FontWeight.w500),
                border: InputBorder.none,
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: Icon(Icons.search_rounded, color: primaryColor, size: 18),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12.5),
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirestoreService.getCollection('drivers').orderBy('driverId').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              final filtered = docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final name = (data['driverName'] ?? '').toString().toLowerCase();
                final phone = (data['driverPhone'] ?? '').toString().toLowerCase();
                final license = (data['driverLicense'] ?? '').toString().toLowerCase();
                final id = (data['driverId'] ?? d.id).toString().toLowerCase();
                final vehicleModel = (data['assignedVehicleModel'] ?? '').toString().toLowerCase();
                final vehiclePlate = (data['assignedVehiclePlate'] ?? '').toString().toLowerCase();
                final vehicleId = (data['assignedVehicleId'] ?? '').toString().toLowerCase();

                return name.contains(_searchQuery) ||
                    phone.contains(_searchQuery) ||
                    license.contains(_searchQuery) ||
                    id.contains(_searchQuery) ||
                    vehicleModel.contains(_searchQuery) ||
                    vehiclePlate.contains(_searchQuery) ||
                    vehicleId.contains(_searchQuery);
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.person_search_rounded, size: 48, color: primaryColor),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'No drivers found',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0A183D)),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                physics: const BouncingScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final driverDoc = filtered[index];
                  final data = driverDoc.data() as Map<String, dynamic>;
                  final isActive = (data['status'] ?? 'Active') == 'Active';
                  final driverId = data['driverId'] ?? driverDoc.id;
                  final assignedVehicleId = data['assignedVehicleId'] as String?;
                  final assignedVehicleModel = data['assignedVehicleModel'] as String?;
                  final assignedVehiclePlate = data['assignedVehiclePlate'] as String?;
                  final hasVehicle = assignedVehicleId != null && assignedVehicleId.isNotEmpty;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
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
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                driverId.toString().replaceAll('DV', ''),
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: primaryColor,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        data['driverName'] ?? 'Unnamed Driver',
                                        style: const TextStyle(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0A183D),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        data['status'] ?? 'Active',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: isActive ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                _driverInfoRow(Icons.phone_rounded, data['driverPhone'] ?? ''),
                                _driverInfoRow(Icons.badge_rounded, data['driverLicense'] ?? ''),
                                _driverInfoRow(Icons.workspace_premium_rounded, '${data['experience'] ?? '0'} yrs experience'),
                                if ((data['driverAddress'] ?? '').isNotEmpty)
                                  _driverInfoRow(Icons.location_on_rounded, data['driverAddress'] ?? ''),

                                const SizedBox(height: 8),
                                // Vehicle Assignment Display
                                if (hasVehicle)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.directions_car_rounded, size: 16, color: primaryColor),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                (assignedVehicleModel?.isNotEmpty ?? false)
                                                    ? assignedVehicleModel!
                                                    : 'Vehicle Assigned',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 12.5,
                                                  color: primaryColor,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (assignedVehiclePlate?.isNotEmpty ?? false)
                                                Text(
                                                  assignedVehiclePlate!,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 11,
                                                    color: Color(0xFF475569),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                                          ),
                                          child: Text(
                                            assignedVehicleId,
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w900,
                                              color: primaryColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.no_crash_outlined, size: 13, color: Color(0xFF94A3B8)),
                                        SizedBox(width: 5),
                                        Text(
                                          'No Vehicle Assigned',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF2563EB)),
                                onPressed: _isSaving ? null : () => _editDriver(driverDoc),
                                tooltip: 'Edit',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                onPressed: _isSaving ? null : () => _deleteDriver(driverId),
                                tooltip: 'Delete',
                              ),
                            ],
                          ),
                        ],
                      ),
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

  Widget _driverInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(icon, size: 13, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
