import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';

class ContractorPage extends StatefulWidget {
  const ContractorPage({super.key});
  @override
  State<ContractorPage> createState() => _ContractorPageState();
}

class _ContractorPageState extends State<ContractorPage> {
  // Stream for contractors table
  Stream<QuerySnapshot<Map<String, dynamic>>> get _contractorsStream =>
      FirestoreService.getCollection('contractors')
          .orderBy('contractorId')
          .snapshots();

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String? _selectedProjectField;
  bool _isSaving = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _addressController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Color get primaryColor => Theme.of(context).primaryColor;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'New Contractor',
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
            constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Form Card: Register New Contractor
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
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
                                  child: Icon(
                                    Icons.engineering_rounded,
                                    color: primaryColor,
                                    size: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Contractor Registration',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0A183D),
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Enter contractor details and project stage',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildProjectFieldDropdown(),
                          const SizedBox(height: 14),
                          _textField(
                            controller: _nameController,
                            label: "Contractor Name",
                            icon: Icons.person_outline_rounded,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? "Please enter contractor name"
                                : null,
                          ),
                          const SizedBox(height: 14),
                          _textField(
                            controller: _numberController,
                            label: "Contact Number",
                            icon: Icons.phone_android_rounded,
                            maxLength: 10,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Please enter contact number";
                              }
                              if (value.length != 10) {
                                return "Contact number must be 10 digits";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          _textField(
                            controller: _addressController,
                            label: "Address",
                            icon: Icons.location_on_outlined,
                            maxLines: 3,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? "Please enter address"
                                : null,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: OutlinedButton(
                                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF0A183D),
                                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: const Text(
                                      "CANCEL",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: Color(0xFF0A183D),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: _isSaving ? null : _onSavePressed,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: _isSaving
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : const Text(
                                            "SAVE",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Directory Header & Search Bar
                  Row(
                    children: [
                      Icon(Icons.badge_rounded, color: primaryColor, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        "All Contractors",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: Color(0xFF0A183D),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

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
                        hintText: 'Search contractor name, stage, ID...',
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
                                icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF64748B)),
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
                  const SizedBox(height: 14),

                  // Stream Directory List
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _contractorsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28.0),
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                            ),
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Text(
                            'Error loading contractors: ${snapshot.error}',
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        );
                      }
                      final docs = snapshot.data?.docs ?? [];

                      final filteredDocs = docs.where((doc) {
                        final data = doc.data();
                        final name = (data['contractorName'] ?? '').toString().toLowerCase();
                        final field = (data['contractorField'] ?? '').toString().toLowerCase();
                        final id = (data['contractorId'] ?? doc.id).toString().toLowerCase();
                        final phone = (data['contactNo'] ?? '').toString().toLowerCase();

                        return _searchQuery.isEmpty ||
                            name.contains(_searchQuery) ||
                            field.contains(_searchQuery) ||
                            id.contains(_searchQuery) ||
                            phone.contains(_searchQuery);
                      }).toList();

                      if (filteredDocs.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.person_search_rounded, color: Color(0xFF94A3B8), size: 40),
                              const SizedBox(height: 8),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No contractors match "$_searchQuery"'
                                    : 'No contractors found.',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: filteredDocs.asMap().entries.map((entry) {
                            final index = entry.key;
                            final doc = entry.value;
                            final data = doc.data();
                            final isLast = index == filteredDocs.length - 1;
                            final String contractorId = data['contractorId'] ?? doc.id;
                            final String rawName = data['contractorName'] ?? '';
                            final String field = data['contractorField'] ?? '';
                            final String contactNo = data['contactNo'] ?? '';

                            // Remove stage suffix if present in name string
                            final String displayName = rawName.contains('_')
                                ? rawName.split('_').first
                                : rawName;

                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                        ),
                                        child: Text(
                                          contractorId,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              displayName,
                                              style: const TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF0A183D),
                                              ),
                                            ),
                                            if (contactNo.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                'Ph: $contactNo',
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (field.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: primaryColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            field,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w800,
                                              color: primaryColor,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (!isLast)
                                  const Divider(
                                    height: 1,
                                    color: Color(0xFFE2E8F0),
                                    indent: 16,
                                    endIndent: 16,
                                  ),
                              ],
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int? maxLength,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
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
          child: TextFormField(
            controller: controller,
            maxLength: maxLength,
            maxLines: maxLines,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            validator: validator,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0A183D),
            ),
            decoration: InputDecoration(
              hintText: 'Enter $label',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Icon(icon, color: primaryColor, size: 20),
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectFieldDropdown() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.getCollection(
        'projectStages',
      ).orderBy('projectStage').snapshots(),
      builder: (context, snapshot) {
        final stages =
            snapshot.data?.docs
                .map((d) => d.data()['projectStage'])
                .whereType<String>()
                .toSet()
                .toList() ??
            [];
        final currentValue = stages.contains(_selectedProjectField)
            ? _selectedProjectField
            : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Project Stage",
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
                initialValue: currentValue,
                isExpanded: true,
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(14),
                decoration: InputDecoration(
                  hintText: "Select Project Stage",
                  hintStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: Icon(
                    Icons.construction_rounded,
                    color: primaryColor,
                    size: 20,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: InputBorder.none,
                ),
                items: stages
                    .map(
                      (stage) => DropdownMenuItem(
                        value: stage,
                        child: Text(stage),
                      ),
                    )
                    .toList(),
                onChanged: stages.isNotEmpty
                    ? (v) => setState(() => _selectedProjectField = v)
                    : null,
                validator: (v) =>
                    v == null ? "Please select a project stage" : null,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0A183D),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onSavePressed() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProjectField == null) return;

    setState(() => _isSaving = true);
    try {
      final contractorId = await _generateNextContractorId();
      final contractorNameCombined =
          '${_nameController.text.trim()}_${_selectedProjectField ?? ''}';
      final data = {
        'contactAddress': _addressController.text.trim(),
        'contactNo': _numberController.text.trim(),
        'contractorField': _selectedProjectField!,
        'contractorId': contractorId,
        'contractorName': contractorNameCombined,
      };
      await FirestoreService.getCollection(
        'contractors',
      ).doc(contractorId).set(data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Contractor added successfully"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save: $e"),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<String> _generateNextContractorId() async {
    final snap = await FirebaseFirestore.instance
        .collection('contractors')
        .orderBy('contractorId', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return 'CT001';
    final lastId = (snap.docs.first['contractorId'] as String?) ?? 'CT000';
    final numPart = int.tryParse(lastId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return 'CT${(numPart + 1).toString().padLeft(3, '0')}';
  }
}
