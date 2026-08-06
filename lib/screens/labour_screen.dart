import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';

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
    // Do NOT use context in dispose! Only dispose controllers and cancel subscriptions.
    designationController.dispose();
    salaryController.dispose();
    updateSalaryController.dispose();
    updateDesignationController.dispose();
    // If you have any listeners or timers, cancel them here.
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
        SnackBar(
          content: Text("Please enter both designation and salary"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // Check for duplicate labour designation
      final duplicateQuery = await FirestoreService.getCollection('labours')
          .where('designation', isEqualTo: designationController.text.trim())
          .get();

      if (duplicateQuery.docs.isNotEmpty) {
        final existingDoc = duplicateQuery.docs.first;
        final existingData = existingDoc.data();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
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

      // Save new labour record
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
          title: Icon(Icons.check_circle, color: Colors.green, size: 48),
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
              child: Text("OK"),
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
        SnackBar(
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
        title: Text("Confirm Update"),
        content: Text("Are you sure you want to update the salary?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("Cancel"),
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
                  SnackBar(
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
                Navigator.of(
                  context,
                ).pop(); // Pop the dialog at the end, when safe
              }
            },
            child: Text("Update"),
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
    

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;
    final horizontalPadding = isDesktop ? 40.0 : (isTablet ? 32.0 : 20.0);
    final maxContentWidth = 1000.0;

    return GlassScaffold(
      title: 'Labour Configuration',
      onBack: () => Navigator.pop(context),
      body: SafeArea(
        bottom: true,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
            child: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: isDesktop ? 32.0 : 20.0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: Column(
                    children: [
                      // Mode Switch Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: mode == LabourMode.newLabour
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey[300],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: isDesktop ? 32 : 24,
                                vertical: isDesktop ? 16 : 12,
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                mode = LabourMode.newLabour;
                              });
                            },
                            child: Text(
                              "New Labour",
                              style: TextStyle(
                                color: mode == LabourMode.newLabour
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: isDesktop ? 16 : 14,
                              ),
                            ),
                          ),
                          SizedBox(width: isDesktop ? 20 : 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: mode == LabourMode.updateLabour
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey[300],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: isDesktop ? 32 : 24,
                                vertical: isDesktop ? 16 : 12,
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                mode = LabourMode.updateLabour;
                                resetUpdateFields();
                              });
                            },
                            child: Text(
                              "Update Labour",
                              style: TextStyle(
                                color: mode == LabourMode.updateLabour
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: isDesktop ? 16 : 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isDesktop ? 32 : 20),
                      if (mode == LabourMode.newLabour) ...[
                        Card(
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(isDesktop ? 32 : 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  "Labour Information",
                                  style: TextStyle(
                                    fontSize: isDesktop ? 22 : 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: isDesktop ? 24 : 16),
                                _buildTextField(
                                  controller: designationController,
                                  label: "Labour Designation",
                                  icon: Icons.engineering_outlined,
                                  isDesktop: isDesktop,
                                  isTablet: isTablet,
                                ),
                                SizedBox(height: isDesktop ? 24 : 16),
                                _buildTextField(
                                  controller: salaryController,
                                  label: "Labour Salary",
                                  icon: Icons.currency_rupee_rounded,
                                  keyboardType: TextInputType.number,
                                  isDesktop: isDesktop,
                                  isTablet: isTablet,
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: isDesktop ? 40 : 30),
                        _buildActionButtons(context, isDesktop, isTablet),
                      ] else ...[
                        Card(
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(isDesktop ? 32 : 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  "Update Labour",
                                  style: TextStyle(
                                    fontSize: isDesktop ? 22 : 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: isDesktop ? 24 : 16),
                                // Designation Dropdown (searchable, editable)
                                _buildDesignationDropdown(isDesktop, isTablet),
                                SizedBox(height: isDesktop ? 24 : 16),
                                // Salary Dropdown (readable, editable with button)
                                _buildSalaryDropdownWithEdit(
                                  isDesktop,
                                  isTablet,
                                ),
                                SizedBox(height: isDesktop ? 32 : 24),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton(
                                      onPressed: updateLabour,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isDesktop ? 32 : 24,
                                          vertical: isDesktop ? 16 : 12,
                                        ),
                                      ),
                                      child: Text(
                                        "Update",
                                        style: TextStyle(
                                          fontSize: isDesktop ? 16 : 14,
                                        ),
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isDesktop ? 32 : 24,
                                          vertical: isDesktop ? 16 : 12,
                                        ),
                                      ),
                                      child: Text(
                                        "Cancel",
                                        style: TextStyle(
                                          fontSize: isDesktop ? 16 : 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: isDesktop ? 48 : 40),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "All Available Labours",
                          style: TextStyle(
                            fontSize: isDesktop ? 20 : 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      SizedBox(height: isDesktop ? 24 : 16),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirestoreService.getCollection(
                          'labours',
                        ).orderBy('labourId').snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          }
                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return Center(child: Text('No labours found.'));
                          }
                          final labours = snapshot.data!.docs;
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columnSpacing: isDesktop ? 40 : 24,
                              headingRowColor: WidgetStateProperty.resolveWith(
                                (states) =>
                                    Theme.of(context).colorScheme.primary,
                              ),
                              border: TableBorder.all(
                                color: Colors.grey,
                                width: 1,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              columns: [
                                DataColumn(
                                  label: Text(
                                    'Labour ID',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: isDesktop ? 16 : 14,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Designation',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: isDesktop ? 16 : 14,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Salary',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: isDesktop ? 16 : 14,
                                    ),
                                  ),
                                ),
                              ],
                              rows: labours.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        data['labourId'] ?? '',
                                        style: TextStyle(
                                          fontSize: isDesktop ? 15 : 13,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        data['designation'] ?? '',
                                        style: TextStyle(
                                          fontSize: isDesktop ? 15 : 13,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        data['salary'] != null
                                            ? '₹${data['salary']}'
                                            : '',
                                        style: TextStyle(
                                          color: Colors.green[800],
                                          fontWeight: FontWeight.w600,
                                          fontSize: isDesktop ? 15 : 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesignationDropdown(bool isDesktop, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Labour Designation",
          style: TextStyle(
            fontSize: isDesktop ? 16 : 14,
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: isDesktop ? 8 : 4),
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text == '') {
              return allLabours.map((e) => e['designation'] as String).toSet();
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
                  style: TextStyle(fontSize: isDesktop ? 16 : 14),
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.engineering_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
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
                      updateSalaryController.text = labour['salary'] ?? '';
                      updateDesignationController.text = val;
                      isSalaryEditable = false;
                    });
                  },
                );
              },
        ),
      ],
    );
  }

  Widget _buildSalaryDropdownWithEdit(bool isDesktop, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Labour Salary",
          style: TextStyle(
            fontSize: isDesktop ? 16 : 14,
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: isDesktop ? 8 : 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: updateSalaryController,
                enabled: isSalaryEditable,
                keyboardType: TextInputType.number,
                style: TextStyle(fontSize: isDesktop ? 16 : 14),
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.currency_rupee_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.edit,
                color: Theme.of(context).colorScheme.primary,
              ),
              onPressed: () {
                setState(() {
                  isSalaryEditable = true;
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    Color? iconColor,
    TextInputType keyboardType = TextInputType.text,
    required bool isDesktop,
    required bool isTablet,
  }) {
    final effectiveIconColor =
        iconColor ?? Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isDesktop ? 16 : 14,
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: isDesktop ? 8 : 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(fontSize: isDesktop ? 16 : 14),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: effectiveIconColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    bool isDesktop,
    bool isTablet,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          context,
          icon: Icons.save,
          label: 'Save',
          color: Theme.of(context).colorScheme.primary,
          onPressed: saveData,
          isDesktop: isDesktop,
          isTablet: isTablet,
        ),
        _buildActionButton(
          context,
          icon: Icons.refresh,
          label: 'Reset',
          color: Colors.orange,
          onPressed: resetFields,
          isDesktop: isDesktop,
          isTablet: isTablet,
        ),
        _buildActionButton(
          context,
          icon: Icons.cancel,
          label: 'Cancel',
          color: Colors.red,
          onPressed: cancelAction,
          isDesktop: isDesktop,
          isTablet: isTablet,
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    required bool isDesktop,
    required bool isTablet,
  }) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          child: IconButton(
            icon: Icon(icon, color: color, size: isDesktop ? 32 : 24),
            onPressed: onPressed,
          ),
        ),
        SizedBox(height: isDesktop ? 8 : 6),
        Text(
          label,
          style: TextStyle(
            fontSize: isDesktop ? 14 : 12,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
