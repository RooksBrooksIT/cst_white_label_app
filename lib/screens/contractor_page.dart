import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';

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
    return GlassScaffold(
      title: 'New Contractor',
      onBack: () => Navigator.pop(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Input form and buttons
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: const Offset(0, 5),
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
                      backgroundColor: primaryColor.withOpacity(0.15),
                      child: Icon(
                        Icons.engineering,
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
                              foregroundColor: primaryColor,
                              side: BorderSide(color: primaryColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              "Cancel",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 6,
                              shadowColor: primaryColor.withOpacity(0.6),
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
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Text(
                                      "Save",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
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
            const SizedBox(height: 36),
            // Section 2: Contractors table
            Text(
              "All Contractors",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 12,
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
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(child: Text('No contractors found.')),
                    );
                  }
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        primaryColor.withOpacity(0.12),
                      ),
                      headingTextStyle: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w700,
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
                            DataCell(Text('${index + 1}')),
                            DataCell(Text(data['contractorName'] ?? '')),
                            DataCell(Text(data['contractorField'] ?? '')),
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
    return TextFormField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: primaryColor, fontWeight: FontWeight.w700),
        filled: true,

        counterText: '',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: primaryColor, width: 2.5),
        ),
      ),
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
        return DropdownButtonFormField<String>(
          value: currentValue,
          decoration: InputDecoration(
            labelText: "Project Stage",
            labelStyle: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w700,
            ),
            filled: true,

            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: primaryColor, width: 2.5),
            ),
          ),
          items: stages
              .map(
                (stage) => DropdownMenuItem(value: stage, child: Text(stage)),
              )
              .toList(),
          onChanged: stages.isNotEmpty
              ? (v) => setState(() => _selectedProjectField = v)
              : null,
          validator: (v) => v == null ? "Please select a project stage" : null,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
          dropdownColor: Colors.white,
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
