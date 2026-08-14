import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/utils/dialog_utils.dart';

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
        title: const Text('Delete Driver'),
        content: const Text('Are you sure you want to delete this driver?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child:
                const Text('Delete', style: TextStyle(color: Colors.red)),
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
    final theme = Theme.of(context);
    final Color darkCardBg = AppTheme.getDarkAccent(theme.primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return GlassScaffold(
      padding: EdgeInsets.zero,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
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
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Text(
                    'Driver Configuration',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.getDarkAccent(AppTheme.primaryColor.value),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // ── Dark pill tab bar ────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: darkCardBg,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: darkCardBg.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  return Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _tabController.animateTo(0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _tabController.index == 0
                                  ? theme.primaryColor
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person_add_rounded,
                                  size: 16,
                                  color: _tabController.index == 0
                                      ? Colors.white
                                      : const Color(0xFFCBD5E1),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'NEW DRIVER',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: _tabController.index == 0
                                        ? Colors.white
                                        : const Color(0xFFCBD5E1),
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
                              color: _tabController.index == 1
                                  ? theme.primaryColor
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_rounded,
                                  size: 16,
                                  color: _tabController.index == 1
                                      ? Colors.white
                                      : const Color(0xFFCBD5E1),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'EXISTING',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: _tabController.index == 1
                                        ? Colors.white
                                        : const Color(0xFFCBD5E1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // ── Tab content ─────────────────────────────────────────────────
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isMobile ? double.infinity : 600,
                  ),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildNewDriverTab(theme, darkCardBg),
                      _buildExistingDriversTab(theme, darkCardBg),
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

  // ── NEW DRIVER TAB ────────────────────────────────────────────────────────
  Widget _buildNewDriverTab(ThemeData theme, Color darkCardBg) {
    final brandIconColor = AppTheme.getDarkAccent(theme.primaryColor);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Form Card
            Container(
              padding: const EdgeInsets.all(22),
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
                  // Card header
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _isEditing
                              ? const Color(0xFF43A047)
                              : const Color(0xFF1E88E5),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (_isEditing
                                      ? const Color(0xFF43A047)
                                      : const Color(0xFF1E88E5))
                                  .withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isEditing ? Icons.edit_rounded : Icons.person_add_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isEditing
                                  ? 'Edit Driver — $_currentDriverId'
                                  : 'Add New Driver',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isEditing
                                  ? 'Update driver details below'
                                  : 'Fill in all required fields',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  _buildWhiteFormField(
                    label: 'Driver Name',
                    icon: Icons.person_rounded,
                    controller: _driverNameController,
                    hintText: 'Enter full name',
                    brandIconColor: brandIconColor,
                    validator: (v) =>
                        v!.isEmpty ? 'Enter driver name' : null,
                  ),
                  const SizedBox(height: 14),
                  _buildWhiteFormField(
                    label: 'Phone Number',
                    icon: Icons.phone_rounded,
                    controller: _driverPhoneController,
                    hintText: 'Enter 10-digit number',
                    keyboardType: TextInputType.number,
                    brandIconColor: brandIconColor,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter phone number';
                      if (v.length != 10)
                        return 'Phone number must be 10 digits';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildWhiteFormField(
                    label: 'License Number',
                    icon: Icons.badge_rounded,
                    controller: _driverLicenseController,
                    hintText: 'Enter license number',
                    brandIconColor: brandIconColor,
                    validator: (v) =>
                        v!.isEmpty ? 'Enter license number' : null,
                  ),
                  const SizedBox(height: 14),
                  _buildWhiteFormField(
                    label: 'Experience (years)',
                    icon: Icons.workspace_premium_rounded,
                    controller: _experienceController,
                    hintText: 'Years of experience',
                    keyboardType: TextInputType.number,
                    brandIconColor: brandIconColor,
                    validator: (v) =>
                        v!.isEmpty ? 'Enter experience' : null,
                  ),
                  const SizedBox(height: 14),
                  _buildWhiteFormField(
                    label: 'Address',
                    icon: Icons.location_on_rounded,
                    controller: _driverAddressController,
                    hintText: 'Enter address',
                    maxLines: 2,
                    brandIconColor: brandIconColor,
                    validator: (v) =>
                        v!.isEmpty ? 'Enter address' : null,
                  ),
                  const SizedBox(height: 16),

                  // Status row
                  const Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                      value: _driverStatus,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      style: const TextStyle(
                        color: Color(0xFF0A183D),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        prefixIcon: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(
                            Icons.toggle_on_rounded,
                            color: brandIconColor,
                            size: 22,
                          ),
                        ),
                      ),
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
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Save / Cancel buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saveDriver,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: const Color(0xFF0A183D),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 6,
                        shadowColor:
                            theme.primaryColor.withValues(alpha: 0.4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isEditing
                                ? Icons.check_rounded
                                : Icons.person_add_rounded,
                            size: 20,
                            color: const Color(0xFF0A183D),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isEditing ? 'UPDATE DRIVER' : 'SAVE DRIVER',
                            style: const TextStyle(
                              color: Color(0xFF0A183D),
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_isEditing) ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _resetForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 4,
                        shadowColor: Colors.red.withValues(alpha: 0.4),
                      ),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),

            if (_isEditing) ...[
              const SizedBox(height: 12),
              const Text(
                '• Tap "Update Driver" to save your changes',
                style: TextStyle(
                  color: Colors.orange,
                  fontStyle: FontStyle.italic,
                  fontSize: 12.5,
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── EXISTING DRIVERS TAB ──────────────────────────────────────────────────
  Widget _buildExistingDriversTab(ThemeData theme, Color darkCardBg) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.getCollection('drivers')
          .orderBy('driverId')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(theme.primaryColor),
            ),
          );
        }

        final drivers = snapshot.data!.docs;

        if (drivers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64,
                    color: theme.primaryColor.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                const Text(
                  'No drivers found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A183D),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Add a new driver in the "NEW DRIVER" tab',
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: drivers.length,
          itemBuilder: (context, index) {
            final driver = drivers[index];
            final data = driver.data() as Map<String, dynamic>;
            final isActive = (data['status'] ?? 'Active') == 'Active';

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: darkCardBg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: darkCardBg.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        data['driverId']?.toString().substring(2) ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: theme.primaryColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                data['driverName'] ?? '',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? Colors.green.withValues(alpha: 0.2)
                                    : Colors.red.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                data['status'] ?? 'Active',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isActive
                                      ? const Color(0xFF4ADE80)
                                      : const Color(0xFFF87171),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _driverInfoRow(Icons.phone_rounded,
                            data['driverPhone'] ?? ''),
                        _driverInfoRow(Icons.badge_rounded,
                            data['driverLicense'] ?? ''),
                        _driverInfoRow(Icons.workspace_premium_rounded,
                            '${data['experience'] ?? '0'} years experience'),
                        if ((data['driverAddress'] ?? '').isNotEmpty)
                          _driverInfoRow(Icons.location_on_rounded,
                              data['driverAddress'] ?? ''),
                      ],
                    ),
                  ),

                  // Actions
                  Column(
                    children: [
                      IconButton(
                        onPressed: () => _editDriver(driver),
                        icon: const Icon(
                          Icons.edit_rounded,
                          color: Color(0xFF60A5FA),
                          size: 20,
                        ),
                        tooltip: 'Edit',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(height: 12),
                      IconButton(
                        onPressed: () => _deleteDriver(data['driverId']),
                        icon: const Icon(
                          Icons.delete_rounded,
                          color: Color(0xFFF87171),
                          size: 20,
                        ),
                        tooltip: 'Delete',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _driverInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFFCBD5E1)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFE2E8F0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhiteFormField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String hintText,
    required Color brandIconColor,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
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
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            maxLines: maxLines,
            validator: validator,
            style: const TextStyle(
              color: Color(0xFF0A183D),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Icon(icon, color: brandIconColor, size: 22),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
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
}
