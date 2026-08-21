import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';

class LabourScreen extends StatefulWidget {
  const LabourScreen({super.key});

  @override
  State<LabourScreen> createState() => _LabourScreenState();
}

enum LabourMode { newLabour, updateLabour }

class _LabourScreenState extends State<LabourScreen> {
  // Mode switching
  LabourMode mode = LabourMode.newLabour;

  // New Labour fields
  String labourId = "LT001";
  final TextEditingController designationController = TextEditingController();
  final TextEditingController salaryController = TextEditingController();
  bool isLoading = false;

  // Update Labour fields
  List<Map<String, dynamic>> allLabours = [];
  String? selectedLabourId;
  String? selectedDesignation;
  String? selectedSalary;
  bool isSalaryEditable = false;
  final TextEditingController updateSalaryController = TextEditingController();
  final TextEditingController updateDesignationController =
      TextEditingController();

  // Pagination & Search state for existing values list
  int _currentPage = 1;
  int _itemsPerPage = 5;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Color get primaryColor => Theme.of(context).primaryColor;

  @override
  void initState() {
    super.initState();
    _getNextLabourId();
    _fetchAllLabours();
  }

  @override
  void dispose() {
    designationController.dispose();
    salaryController.dispose();
    updateSalaryController.dispose();
    updateDesignationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getNextLabourId() async {
    setState(() => isLoading = true);
    try {
      final QuerySnapshot snapshot = await FirestoreService.getCollection(
        'labours',
      ).orderBy('labourId', descending: true).limit(1).get();

      if (snapshot.docs.isNotEmpty) {
        final String lastId = snapshot.docs.first['labourId'] ?? '';
        final int lastNum = int.tryParse(lastId.replaceAll('LT', '')) ?? 0;
        final int nextNum = lastNum + 1;
        setState(() {
          labourId = 'LT${nextNum.toString().padLeft(3, '0')}';
          isLoading = false;
        });
      } else {
        setState(() {
          labourId = 'LT001';
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          labourId = 'LT001';
          isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchAllLabours() async {
    try {
      final QuerySnapshot snapshot = await FirestoreService.getCollection(
        'labours',
      ).orderBy('designation').get();
      if (mounted) {
        setState(() {
          allLabours = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'labourId': data['labourId'] ?? doc.id,
              'designation': data['designation'] ?? '',
              'salary': data['salary'] ?? '',
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching all labours: $e');
    }
  }

  void resetFields() {
    designationController.clear();
    salaryController.clear();
  }

  void resetUpdateFields() {
    selectedLabourId = null;
    selectedDesignation = null;
    selectedSalary = null;
    updateSalaryController.clear();
    updateDesignationController.clear();
    isSalaryEditable = false;
  }

  Future<void> saveData() async {
    if (isLoading) return;
    if (designationController.text.trim().isEmpty ||
        salaryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter both designation and salary"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final duplicateQuery = await FirestoreService.getCollection('labours')
          .where('designation', isEqualTo: designationController.text.trim())
          .get();

      if (duplicateQuery.docs.isNotEmpty) {
        final existingDoc = duplicateQuery.docs.first;
        final existingData = existingDoc.data();

        if (!mounted) return;
        final overwrite = await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Designation Exists',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A183D)),
            ),
            content: Text(
              'Labour designation "${designationController.text.trim()}" already exists with ID "${existingDoc['labourId'] ?? existingDoc.id}" and Salary "₹${existingData['salary'] ?? ''}".\n\nWould you like to overwrite it?',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('CANCEL', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: const Text('OVERWRITE'),
              ),
            ],
          ),
        );

        if (overwrite == true) {
          await FirestoreService.getCollection('labours').doc(existingDoc.id).update({
            'salary': salaryController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Labour salary updated successfully!"),
              backgroundColor: Colors.green,
            ),
          );
          resetFields();
          await _fetchAllLabours();
        }
        setState(() => isLoading = false);
        return;
      }

      await FirestoreService.getCollection('labours').doc(labourId).set({
        'labourId': labourId,
        'designation': designationController.text.trim(),
        'salary': salaryController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Labour configuration saved successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      resetFields();
      await _getNextLabourId();
      await _fetchAllLabours();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error saving data: $e"),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => isLoading = false);
    }
  }

  Future<void> updateLabour() async {
    if (selectedLabourId == null || selectedLabourId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a labour designation to update"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (updateSalaryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Salary cannot be empty"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await FirestoreService.getCollection('labours').doc(selectedLabourId).update({
        'salary': updateSalaryController.text.trim(),
        'designation': updateDesignationController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Labour updated successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      resetUpdateFields();
      await _fetchAllLabours();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error updating labour: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _deleteLabour(String docId, String designation) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Labour',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A183D)),
        ),
        content: Text(
          'Are you sure you want to delete "$designation" ($docId)?',
          style: const TextStyle(color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('CANCEL', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirestoreService.getCollection('labours').doc(docId).delete();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Labour deleted successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        await _fetchAllLabours();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error deleting labour: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Labour Configuration',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
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
        child: Column(
          children: [
            // Mode Switcher Bar (NEW LABOUR / UPDATE LABOUR)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              padding: const EdgeInsets.all(4),
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
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => mode = LabourMode.newLabour),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: mode == LabourMode.newLabour
                              ? primaryColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'NEW LABOUR',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: mode == LabourMode.newLabour
                                ? Colors.white
                                : const Color(0xFF0A183D),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        mode = LabourMode.updateLabour;
                        resetUpdateFields();
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: mode == LabourMode.updateLabour
                              ? primaryColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'UPDATE LABOUR',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: mode == LabourMode.updateLabour
                                ? Colors.white
                                : const Color(0xFF0A183D),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content Body
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
                  child: isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                          ),
                        )
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Column(
                            children: [
                              mode == LabourMode.newLabour
                                  ? _buildNewSection()
                                  : _buildUpdateSection(),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NEW LABOUR SECTION
  Widget _buildNewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Form Card
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.person_add_rounded,
                    color: Color(0xFF3B82F6),
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Labour Information',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0A183D),
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Enter designation and salary details',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      labourId,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _buildWhiteTextField(
                label: 'Labour Designation',
                icon: Icons.engineering_rounded,
                controller: designationController,
                hintText: 'Enter designation (e.g. Mason, Electrician)',
              ),
              const SizedBox(height: 14),
              _buildWhiteTextField(
                label: 'Labour Salary (₹)',
                icon: Icons.currency_rupee_rounded,
                controller: salaryController,
                hintText: 'Enter salary amount',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Save Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: saveData,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 2,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.save_rounded, size: 18, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'SAVE',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),

        _buildLabourList(),
      ],
    );
  }

  // UPDATE LABOUR SECTION
  Widget _buildUpdateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    color: Color(0xFF16A34A),
                    size: 24,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Update Labour',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0A183D),
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Select a labour and update their salary',
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

              const Text(
                'Labour Designation',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0A183D),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text == '') {
                      return allLabours
                          .map((e) => e['designation'] as String)
                          .where((des) => des.isNotEmpty)
                          .toSet();
                    }
                    return allLabours
                        .map((e) => e['designation'] as String)
                        .where(
                          (option) => option.toLowerCase().contains(
                            textEditingValue.text.toLowerCase(),
                          ),
                        )
                        .toSet();
                  },
                  onSelected: (String selection) {
                    final labour = allLabours.firstWhere(
                      (e) => e['designation'] == selection,
                      orElse: () => {},
                    );
                    setState(() {
                      selectedDesignation = selection;
                      selectedLabourId = labour['labourId'];
                      selectedSalary = labour['salary'];
                      updateSalaryController.text = labour['salary'] ?? '';
                      updateDesignationController.text = selection;
                      isSalaryEditable = true;
                    });
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onEditingComplete) {
                    controller.text = selectedDesignation ?? '';
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      style: const TextStyle(
                        color: Color(0xFF0A183D),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search designation...',
                        hintStyle: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(
                            Icons.engineering_rounded,
                            color: primaryColor,
                            size: 20,
                          ),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          selectedDesignation = val;
                          final labour = allLabours.firstWhere(
                            (e) => e['designation'] == val,
                            orElse: () => {},
                          );
                          selectedLabourId = labour['labourId'];
                          selectedSalary = labour['salary'];
                          updateSalaryController.text =
                              labour['salary'] ?? '';
                          updateDesignationController.text = val;
                          isSalaryEditable = true;
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),

              const Text(
                'Labour Salary (₹)',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0A183D),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: TextField(
                        controller: updateSalaryController,
                        enabled: isSalaryEditable,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: Color(0xFF0A183D),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter salary amount',
                          hintStyle: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13.5,
                          ),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Icon(
                              Icons.currency_rupee_rounded,
                              color: primaryColor,
                              size: 20,
                            ),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSalaryEditable
                          ? const Color(0xFFEF4444)
                          : primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        isSalaryEditable
                            ? Icons.close_rounded
                            : Icons.edit_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => isSalaryEditable = !isSalaryEditable),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: updateLabour,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 2,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_rounded, size: 18, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'UPDATE LABOUR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),

        _buildLabourList(),
      ],
    );
  }

  // EXISTING LABOUR LIST WITH SEARCH & PAGINATION
  Widget _buildLabourList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.groups_rounded,
              color: primaryColor,
              size: 22,
            ),
            const SizedBox(width: 8),
            const Text(
              'All Available Labours',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A183D),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Search field & Rows per page selector
        Row(
          children: [
            Expanded(
              child: Container(
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
                      _currentPage = 1;
                    });
                  },
                  style: const TextStyle(
                    color: Color(0xFF0A183D),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search designation or ID...',
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
                                _currentPage = 1;
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _itemsPerPage,
                  icon: const Icon(
                    Icons.arrow_drop_down_rounded,
                    color: Color(0xFF0A183D),
                  ),
                  style: const TextStyle(
                    color: Color(0xFF0A183D),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  onChanged: (newVal) {
                    if (newVal != null) {
                      setState(() {
                        _itemsPerPage = newVal;
                        _currentPage = 1;
                      });
                    }
                  },
                  items: [5, 10, 15, 20].map((int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text('$value / page'),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        StreamBuilder<QuerySnapshot>(
          stream: FirestoreService.getCollection('labours')
              .orderBy('labourId')
              .snapshots(),
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
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.engineering_outlined, color: Color(0xFF94A3B8), size: 40),
                    SizedBox(height: 8),
                    Text(
                      'No labours found.',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }

            final allDocs = snapshot.data!.docs;
            final filteredDocs = allDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final id = (data['labourId'] ?? '').toString().toLowerCase();
              final des = (data['designation'] ?? '').toString().toLowerCase();
              return id.contains(_searchQuery) || des.contains(_searchQuery);
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
                child: Center(
                  child: Text(
                    'No labours match "$_searchQuery"',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }

            final totalItems = filteredDocs.length;
            final totalPages = (totalItems / _itemsPerPage).ceil().clamp(1, 99999);
            if (_currentPage > totalPages) {
              _currentPage = totalPages;
            }

            final startIndex = (_currentPage - 1) * _itemsPerPage;
            final endIndex = (startIndex + _itemsPerPage).clamp(0, totalItems);
            final pageDocs = filteredDocs.sublist(startIndex, endIndex);

            return Column(
              children: [
                Container(
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
                    children: pageDocs.asMap().entries.map((entry) {
                      final index = entry.key;
                      final doc = entry.value;
                      final data = doc.data() as Map<String, dynamic>;
                      final isLast = index == pageDocs.length - 1;
                      final String docId = data['labourId'] ?? doc.id;
                      final String designation = data['designation'] ?? '';
                      final String salary = data['salary'] ?? '';

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
                                    docId,
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
                                        designation,
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0A183D),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Text(
                                    salary.isNotEmpty ? '₹$salary' : '—',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF059669),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  icon: Icon(
                                    Icons.edit_rounded,
                                    size: 18,
                                    color: primaryColor,
                                  ),
                                  tooltip: 'Edit Labour',
                                  onPressed: () {
                                    setState(() {
                                      mode = LabourMode.updateLabour;
                                      selectedLabourId = docId;
                                      selectedDesignation = designation;
                                      selectedSalary = salary;
                                      updateSalaryController.text = salary;
                                      updateDesignationController.text = designation;
                                      isSalaryEditable = true;
                                    });
                                  },
                                ),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: Color(0xFFEF4444),
                                  ),
                                  tooltip: 'Delete Labour',
                                  onPressed: () => _deleteLabour(docId, designation),
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
                ),
                const SizedBox(height: 12),

                _buildPaginationBar(
                  currentPage: _currentPage,
                  totalPages: totalPages,
                  totalItems: totalItems,
                  itemsPerPage: _itemsPerPage,
                  onPageChanged: (newPage) {
                    setState(() => _currentPage = newPage);
                  },
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildPaginationBar({
    required int currentPage,
    required int totalPages,
    required int totalItems,
    required int itemsPerPage,
    required Function(int) onPageChanged,
  }) {
    if (totalItems == 0) return const SizedBox.shrink();

    final startItem = (currentPage - 1) * itemsPerPage + 1;
    final endItem = (currentPage * itemsPerPage).clamp(1, totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              '$startItem–$endItem of $totalItems',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                icon: Icon(
                  Icons.first_page_rounded,
                  size: 18,
                  color: currentPage > 1 ? primaryColor : Colors.grey.shade300,
                ),
                onPressed: currentPage > 1 ? () => onPageChanged(1) : null,
                tooltip: 'First Page',
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                icon: Icon(
                  Icons.chevron_left_rounded,
                  size: 18,
                  color: currentPage > 1 ? primaryColor : Colors.grey.shade300,
                ),
                onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
                tooltip: 'Previous Page',
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$currentPage/$totalPages',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                icon: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: currentPage < totalPages ? primaryColor : Colors.grey.shade300,
                ),
                onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
                tooltip: 'Next Page',
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                icon: Icon(
                  Icons.last_page_rounded,
                  size: 18,
                  color: currentPage < totalPages ? primaryColor : Colors.grey.shade300,
                ),
                onPressed: currentPage < totalPages ? () => onPageChanged(totalPages) : null,
                tooltip: 'Last Page',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWhiteTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final brandIconColor = Theme.of(context).primaryColor;
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
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(
              color: Color(0xFF0A183D),
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Icon(icon, color: brandIconColor, size: 20),
              ),
              border: InputBorder.none,
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
