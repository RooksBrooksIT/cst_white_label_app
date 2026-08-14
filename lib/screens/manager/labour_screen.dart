import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';

class LabourScreen extends StatefulWidget {
  const LabourScreen({super.key});

  @override
  _LabourScreenState createState() => _LabourScreenState();
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
    super.dispose();
  }

  Future<void> _getNextLabourId() async {
    setState(() => isLoading = true);
    final QuerySnapshot snapshot = await FirestoreService.getCollection(
      'labours',
    ).orderBy('labourId', descending: true).limit(1).get();

    if (snapshot.docs.isNotEmpty) {
      final String lastId = snapshot.docs.first['labourId'];
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
  }

  Future<void> _fetchAllLabours() async {
    final QuerySnapshot snapshot = await FirestoreService.getCollection(
      'labours',
    ).orderBy('designation').get();
    setState(() {
      allLabours = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'labourId': data['labourId'],
          'designation': data['designation'],
          'salary': data['salary'],
        };
      }).toList();
    });
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Labour designation already exists. Switching to update view.',
            ),
            backgroundColor: Colors.orange,
          ),
        );

        setState(() {
          mode = LabourMode.updateLabour;
          selectedLabourId = existingData['labourId'];
          selectedDesignation = existingData['designation'];
          selectedSalary = existingData['salary'];
          updateSalaryController.text = existingData['salary'] ?? '';
          updateDesignationController.text = existingData['designation'] ?? '';
          isSalaryEditable = false;
          isLoading = false;
        });
        return;
      }

      await FirestoreService.getCollection('labours').doc(labourId).set({
        'labourId': labourId,
        'designation': designationController.text.trim(),
        'salary': salaryController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Icon(Icons.check_circle, color: Colors.green, size: 48),
          content: Text(
            "New labour added successfully!\n\nLabour ID: $labourId",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                resetFields();
                _getNextLabourId();
                _fetchAllLabours();
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error saving data: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> updateLabour() async {
    if (selectedLabourId == null ||
        updateSalaryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a labour and enter salary."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Update"),
        content: const Text("Are you sure you want to update the salary?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              setState(() => isLoading = true);
              try {
                await FirestoreService.getCollection('labours')
                    .doc(selectedLabourId)
                    .update({'salary': updateSalaryController.text.trim()});
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Salary updated successfully!"),
                    backgroundColor: Colors.green,
                  ),
                );
                _fetchAllLabours();
                resetUpdateFields();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Error updating salary: $e"),
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                if (!mounted) return;
                setState(() => isLoading = false);
                Navigator.of(context).pop();
              }
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  void cancelAction() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color darkCardBg = AppTheme.getDarkAccent(theme.primaryColor);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

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
                    'Labour Configuration',
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

            // ── Tab Bar ─────────────────────────────────────────────────────
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
                              ? theme.primaryColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'NEW LABOUR',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: mode == LabourMode.newLabour
                                ? Colors.white
                                : const Color(0xFFCBD5E1),
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
                              ? theme.primaryColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'UPDATE LABOUR',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: mode == LabourMode.updateLabour
                                ? Colors.white
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ─────────────────────────────────────────────────────
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isMobile ? double.infinity : 600,
                  ),
                  child: isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.primaryColor,
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          child: mode == LabourMode.newLabour
                              ? _buildNewSection(theme, darkCardBg)
                              : _buildUpdateSection(theme, darkCardBg),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── NEW LABOUR SECTION ───────────────────────────────────────────────────
  Widget _buildNewSection(ThemeData theme, Color darkCardBg) {
    return Column(
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
                      color: const Color(0xFF1E88E5),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E88E5).withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_add_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Labour Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Enter designation and salary details',
                          style: TextStyle(
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
              _buildWhiteTextField(
                label: 'Labour Designation',
                icon: Icons.engineering_rounded,
                controller: designationController,
                hintText: 'Enter designation',
              ),
              const SizedBox(height: 16),
              _buildWhiteTextField(
                label: 'Labour Salary',
                icon: Icons.currency_rupee_rounded,
                controller: salaryController,
                hintText: 'Enter salary amount',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                label: 'SAVE',
                icon: Icons.save_rounded,
                color: theme.primaryColor,
                onPressed: saveData,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                label: 'RESET',
                icon: Icons.refresh_rounded,
                color: Colors.orange,
                onPressed: () => setState(() => resetFields()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                label: 'CANCEL',
                icon: Icons.close_rounded,
                color: Colors.red,
                onPressed: cancelAction,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // All Available Labours list
        _buildLabourList(theme, darkCardBg),
      ],
    );
  }

  // ── UPDATE LABOUR SECTION ────────────────────────────────────────────────
  Widget _buildUpdateSection(ThemeData theme, Color darkCardBg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF43A047),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF43A047).withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Update Labour',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Select a labour and update their salary',
                          style: TextStyle(
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

              // Designation label + autocomplete
              const Text(
                'Labour Designation',
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
                child: Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text == '') {
                      return allLabours
                          .map((e) => e['designation'] as String)
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
                      isSalaryEditable = false;
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
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search designation...',
                        hintStyle: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(
                            Icons.engineering_rounded,
                            color: AppTheme.getDarkAccent(
                              Theme.of(context).primaryColor,
                            ),
                            size: 22,
                          ),
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
                          isSalaryEditable = false;
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Salary label + field + edit toggle
              const Text(
                'Labour Salary',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
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
                      child: TextField(
                        controller: updateSalaryController,
                        enabled: isSalaryEditable,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: Color(0xFF0A183D),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter salary',
                          hintStyle: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 14,
                          ),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Icon(
                              Icons.currency_rupee_rounded,
                              color: AppTheme.getDarkAccent(
                                Theme.of(context).primaryColor,
                              ),
                              size: 22,
                            ),
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
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSalaryEditable
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF1E88E5),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: (isSalaryEditable
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF1E88E5))
                              .withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        isSalaryEditable
                            ? Icons.close_rounded
                            : Icons.edit_rounded,
                        color: Colors.white,
                        size: 22,
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

        // Update + Cancel buttons
        Row(
          children: [
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: updateLabour,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: const Color(0xFF0A183D),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 6,
                    shadowColor:
                        Theme.of(context).primaryColor.withValues(alpha: 0.4),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_rounded, size: 20,
                          color: Color(0xFF0A183D)),
                      SizedBox(width: 8),
                      Text(
                        'UPDATE LABOUR',
                        style: TextStyle(
                          color: Color(0xFF0A183D),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () => setState(() => resetUpdateFields()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'RESET',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A183D),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        _buildLabourList(Theme.of(context), darkCardBg),
      ],
    );
  }

  // ── LABOUR LIST ──────────────────────────────────────────────────────────
  Widget _buildLabourList(ThemeData theme, Color darkCardBg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.groups_rounded,
                color: theme.primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              'All Available Labours',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: theme.primaryColor,
                letterSpacing: -0.2,
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
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(theme.primaryColor),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: darkCardBg.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    'No labours found.',
                    style: TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }

            final labours = snapshot.data!.docs;
            return Container(
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
              child: Column(
                children: labours.asMap().entries.map((entry) {
                  final index = entry.key;
                  final doc = entry.value;
                  final data = doc.data() as Map<String, dynamic>;
                  final isLast = index == labours.length - 1;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            // ID badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: theme.primaryColor
                                    .withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                data['labourId'] ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: theme.primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                data['designation'] ?? '',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            // Salary chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                data['salary'] != null
                                    ? '₹${data['salary']}'
                                    : '—',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF4ADE80),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Divider(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.08),
                          indent: 18,
                          endIndent: 18,
                        ),
                    ],
                  );
                }).toList(),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── SHARED HELPERS ───────────────────────────────────────────────────────
  Widget _buildWhiteTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final brandIconColor =
        AppTheme.getDarkAccent(Theme.of(context).primaryColor);
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
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
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

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 4,
          shadowColor: color.withValues(alpha: 0.4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
