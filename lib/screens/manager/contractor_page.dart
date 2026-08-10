import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';

class ContractorPage extends StatefulWidget {
  const ContractorPage({super.key});
  @override
  State<ContractorPage> createState() => _ContractorPageState();
}

class _ContractorPageState extends State<ContractorPage> {
  // For displaying contractors table
  // Show new contractors at the end by ordering by contractorId ascending
  Stream<QuerySnapshot<Map<String, dynamic>>> get _contractorsStream =>
      FirestoreService.getCollection(
        'contractors',
      ).orderBy('contractorId').snapshots();

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  String? _selectedProjectField;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Color get primaryColor => Theme.of(context).colorScheme.primary;

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    final darkCardBg = AppTheme.getDarkAccent(primaryColor);

    return GlassScaffold(
      title: 'New Contractor',
      onBack: () => Navigator.pop(context),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section 1: Input form and buttons
                Container(
                  padding: const EdgeInsets.all(24),
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Contractor illustration / avatar
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: primaryColor.withValues(alpha: 0.18),
                          child: Icon(
                            Icons.engineering_rounded,
                            color: primaryColor,
                            size: 44,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildProjectFieldDropdown(),
                        const SizedBox(height: 20),
                        _textField(
                          controller: _nameController,
                          label: "Contractor Name",
                          validator: (v) => v == null || v.trim().isEmpty
                              ? "Please enter name"
                              : null,
                        ),
                        const SizedBox(height: 20),
                        _textField(
                          controller: _numberController,
                          label: "Contact Number",
                          maxLength: 10,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Please enter contractor number";
                            }
                            if (value.length != 10) {
                              return "Contact number must be 10 digits";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        _textField(
                          controller: _addressController,
                          label: "Address",
                          maxLines: 3,
                          validator: (v) => v == null || v.trim().isEmpty
                              ? "Please enter address"
                              : null,
                        ),
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isSaving
                                    ? null
                                    : () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.4),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: const Text(
                                  "Cancel",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _onSavePressed,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: const Color(0xFF0A183D),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 6,
                                  shadowColor: primaryColor.withValues(alpha: 0.4),
                                ),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: _isSaving
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Color(0xFF0A183D),
                                                ),
                                          ),
                                        )
                                      : const Text(
                                          "Save",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
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
                const SizedBox(height: 32),
                // Section 2: Contractors table
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A183D),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "All Contractors",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: Color(0xFF0A183D),
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
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
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _contractorsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(30),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(30),
                          child: Text(
                            'Error loading contractors',
                            style: TextStyle(
                              color: Colors.red.shade400,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }
                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(30),
                          child: Center(
                            child: Text(
                              'No contractors found.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            Colors.white.withValues(alpha: 0.1),
                          ),
                          headingTextStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                          columnSpacing: 36,
                          dataRowHeight: 52,
                          columns: const [
                            DataColumn(label: Text('S.No.')),
                            DataColumn(label: Text('Contractor Name')),
                            DataColumn(label: Text('Project Stage')),
                          ],
                          rows: List<DataRow>.generate(docs.length, (index) {
                            final data = docs[index].data();
                            return DataRow(
                              cells: [
                                DataCell(Text(
                                  '${index + 1}',
                                  style: const TextStyle(color: Colors.white),
                                )),
                                DataCell(Text(
                                  data['contractorName'] ?? '',
                                  style: const TextStyle(color: Colors.white),
                                )),
                                DataCell(Text(
                                  data['contractorField'] ?? '',
                                  style: const TextStyle(color: Colors.white),
                                )),
                              ],
                            );
                          }),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Custom beautiful filled textfield
  Widget _textField({
    required TextEditingController controller,
    required String label,
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
            maxLength: maxLength,
            maxLines: maxLines,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            validator: validator,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0A183D),
            ),
            decoration: InputDecoration(
              hintText: 'Enter $label',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              filled: false,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
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
                value: currentValue,
                isExpanded: true,
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(16),
                decoration: InputDecoration(
                  hintText: "Select Project Stage",
                  hintStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
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
          backgroundColor: primaryColor,
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
