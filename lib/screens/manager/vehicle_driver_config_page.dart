import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/utils/dialog_utils.dart';
import 'package:demo_cst/utils/responsive.dart';

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
  String _searchQuery = '';

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

  Future<String> _getNextDriverId() async {
    final snapshot = await FirestoreService.getCollection('drivers')
        .orderBy('driverId', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return 'DV001';

    final lastDriverId = snapshot.docs.first['driverId'] as String? ?? 'DV000';
    final numberStr = lastDriverId.replaceAll(RegExp(r'[^0-9]'), '');
    final number = int.tryParse(numberStr) ?? 0;
    return 'DV${(number + 1).toString().padLeft(3, '0')}';
  }

  Future<void> _saveDriver() async {
    if (!_formKey.currentState!.validate()) return;

    final driverId =
        _isEditing ? _currentDriverId : await _getNextDriverId();

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

    await FirestoreService.getCollection('drivers').doc(driverId).set(data);

    if (mounted) {
      await DialogUtils.showSuccessDialog(
        context,
        message: 'Driver ${_isEditing ? 'updated' : 'saved'} successfully!',
      );
    }

    if (!_isEditing) {
      _resetForm();
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
    });
  }

  Future<void> _deleteDriver(String driverId) async {
    final result = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Driver', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete driver $driverId?'),
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
      await FirestoreService.getCollection('drivers').doc(driverId).delete();
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
                      'NEW DRIVER',
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
                    Text(
                      'EXISTING DRIVERS',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: _tabController.index == 1 ? Colors.white : const Color(0xFF64748B),
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
                  _buildCustomTextField(
                    label: 'Driver Name *',
                    child: TextFormField(
                      controller: _driverNameController,
                      style: const TextStyle(color: Color(0xFF0A183D), fontSize: 14.5, fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(
                        hintText: 'Enter full name',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        prefixIcon: Icon(Icons.person_rounded, color: Color(0xFF64748B), size: 20),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Enter driver name' : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCustomTextField(
                    label: 'Phone Number *',
                    child: TextFormField(
                      controller: _driverPhoneController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Color(0xFF0A183D), fontSize: 14.5, fontWeight: FontWeight.w700),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: const InputDecoration(
                        hintText: 'Enter 10-digit phone number',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        prefixIcon: Icon(Icons.phone_rounded, color: Color(0xFF64748B), size: 20),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter phone number';
                        if (v.length != 10) return 'Phone number must be 10 digits';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCustomTextField(
                    label: 'License Number *',
                    child: TextFormField(
                      controller: _driverLicenseController,
                      style: const TextStyle(color: Color(0xFF0A183D), fontSize: 14.5, fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(
                        hintText: 'Enter driver license number',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        prefixIcon: Icon(Icons.badge_rounded, color: Color(0xFF64748B), size: 20),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Enter license number' : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCustomTextField(
                    label: 'Experience (years) *',
                    child: TextFormField(
                      controller: _experienceController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Color(0xFF0A183D), fontSize: 14.5, fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(
                        hintText: 'Years of driving experience',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        prefixIcon: Icon(Icons.workspace_premium_rounded, color: Color(0xFF64748B), size: 20),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Enter experience' : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCustomTextField(
                    label: 'Address *',
                    child: TextFormField(
                      controller: _driverAddressController,
                      maxLines: 2,
                      style: const TextStyle(color: Color(0xFF0A183D), fontSize: 14.5, fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(
                        hintText: 'Enter resident address',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        prefixIcon: Icon(Icons.location_on_rounded, color: Color(0xFF64748B), size: 20),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Enter address' : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCustomTextField(
                    label: 'Status *',
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _driverStatus,
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      style: const TextStyle(color: Color(0xFF0A183D), fontSize: 14.5, fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        prefixIcon: Icon(Icons.toggle_on_rounded, color: Color(0xFF64748B), size: 20),
                      ),
                      items: ['Active', 'Inactive']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) => setState(() => _driverStatus = val!),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (_isEditing) ...[
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: _resetForm,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saveDriver,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                      child: Text(
                        _isEditing ? 'UPDATE DRIVER' : 'SAVE DRIVER',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
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

  Widget _buildCustomTextField({required String label, required Widget child}) {
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

  Widget _buildExistingDriversTab(Color primaryColor) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              style: const TextStyle(color: Color(0xFF0A183D), fontSize: 13.5, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Search driver by name, phone, or license...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search_rounded, color: primaryColor, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                return name.contains(_searchQuery) ||
                    phone.contains(_searchQuery) ||
                    license.contains(_searchQuery) ||
                    id.contains(_searchQuery);
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
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF2563EB)),
                                onPressed: () => _editDriver(driverDoc),
                                tooltip: 'Edit',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                onPressed: () => _deleteDriver(driverId),
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
