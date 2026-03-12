import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

class MaterialAtSiteEntryPage extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;
  const MaterialAtSiteEntryPage({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  State<MaterialAtSiteEntryPage> createState() =>
      _MaterialAtSiteEntryPageState();
}

class _MaterialAtSiteEntryPageState extends State<MaterialAtSiteEntryPage> {
  // Color Scheme
  final Color primaryColor = const Color(0xFF0B3470);
  final Color accentColor = const Color(0xFFD9A441);
  final Color backgroundColor = const Color(0xFFF5F5F5);
  final Color cardColor = Colors.white;
  final Color errorColor = const Color(0xFFD32F2F);
  final Color successColor = const Color(0xFF388E3C);

  // Form State
  final TextEditingController siteIdController = TextEditingController();
  final TextEditingController siteLocationController = TextEditingController();
  final TextEditingController supervisorNameController =
      TextEditingController();
  final TextEditingController quantityController = TextEditingController();

  DateTime selectedDate = DateTime.now();

  // New state for site dropdown
  List<String> assignedSiteIds = [];
  String? selectedSiteId;

  // For update, available existing dates
  List<DateTime> availableUpdateDates = [];

  // Data State
  List<String> materialOptions = [];
  List<String> unitOptions = [];
  String? selectedMaterial;
  String? selectedUnit;
  List<Map<String, dynamic>> materialEntries = [];

  // Loading States
  bool isLoading = true;
  bool dropdownsLoading = true;
  String? errorMsg;

  // Update Tab State
  List<Map<String, dynamic>> updateMaterials = [];
  List<TextEditingController> updateQuantityControllers = [];
  bool isUpdateLoading = false;
  String? updateErrorMsg;
  String? updateDocId;

  @override
  void initState() {
    super.initState();
    supervisorNameController.text = widget.supervisorName;
    fetchSiteDetails();
    fetchDropdownOptions();
  }

  Future<void> fetchSiteDetails() async {
    setState(() {
      isLoading = true;
      errorMsg = null;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('siteSupervisorMap')
          .where('supervisor', isEqualTo: widget.supervisorName)
          .get();
      if (snapshot.docs.isEmpty) {
        setState(() {
          errorMsg = "No site mapping found for this supervisor";
        });
        return;
      }
      assignedSiteIds = snapshot.docs
          .map((doc) => doc['site']?.toString() ?? '')
          .where((siteId) => siteId.isNotEmpty)
          .toList();
      if (assignedSiteIds.isNotEmpty) {
        selectedSiteId = assignedSiteIds.first;
        siteIdController.text = selectedSiteId!;
        final firstSiteData = snapshot.docs.first.data();
        siteLocationController.text =
            firstSiteData['location']?.toString() ?? '';
      }
    } catch (e) {
      setState(() {
        errorMsg = "Failed to load site details: ${e.toString()}";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchDropdownOptions() async {
    try {
      final materialsSnapshot = await FirebaseFirestore.instance
          .collection('materials')
          .get();
      final unitsSnapshot = await FirebaseFirestore.instance
          .collection('materialUnits')
          .get();

      setState(() {
        materialOptions = materialsSnapshot.docs
            .map(
              (doc) => doc.data().containsKey('materialName')
                  ? doc['materialName'].toString()
                  : '',
            )
            .where((e) => e.isNotEmpty)
            .toList();
        unitOptions = unitsSnapshot.docs
            .map(
              (doc) => doc.data().containsKey('matUnit')
                  ? doc['matUnit'].toString()
                  : '',
            )
            .where((e) => e.isNotEmpty)
            .toList();
        if (materialOptions.isNotEmpty) {
          selectedMaterial = materialOptions.first;
        }
        if (unitOptions.isNotEmpty) selectedUnit = unitOptions.first;
        dropdownsLoading = false;
      });
    } catch (e) {
      setState(() {
        dropdownsLoading = false;
        errorMsg = "Failed to load dropdown options: ${e.toString()}";
      });
    }
  }

  Future<void> fetchAvailableUpdateDates() async {
    if (selectedSiteId == null) return;
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('materialsAtSite')
          .where('siteId', isEqualTo: selectedSiteId)
          .get();

      setState(() {
        availableUpdateDates = querySnapshot.docs.map((doc) {
          final Timestamp? ts = doc['date'] as Timestamp?;
          return ts?.toDate() ?? DateTime.now();
        }).toList();
      });
    } catch (e) {
      setState(() {
        availableUpdateDates = [];
      });
      _showSnackBar(
        'Failed to fetch update dates: ${e.toString()}',
        isError: true,
      );
    }
  }

  Widget _buildUpdateDateSelector() {
    if (availableUpdateDates.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No dates available for update',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }
    return DropdownButtonFormField<DateTime>(
      value: availableUpdateDates.contains(selectedDate) ? selectedDate : null,
      items: availableUpdateDates.map((date) {
        return DropdownMenuItem(
          value: date,
          child: Text(DateFormat('MMMM d, yyyy').format(date)),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() {
            selectedDate = val;
          });
          fetchMaterialsForUpdate(); // Reload materials for chosen date
        }
      },
      decoration: InputDecoration(
        labelText: 'Select Date to Update',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
    );
  }

  Future<void> fetchMaterialsForUpdate() async {
    setState(() {
      isUpdateLoading = true;
      updateErrorMsg = null;
      updateMaterials = [];
      updateQuantityControllers = [];
    });

    try {
      final siteId = selectedSiteId?.trim() ?? '';
      if (siteId.isEmpty) {
        setState(() => updateErrorMsg = 'Site ID is required');
        return;
      }

      await fetchAvailableUpdateDates();

      final docId = '${siteId}_${DateFormat('yyyyMMdd').format(selectedDate)}';
      updateDocId = docId;

      final docSnap = await FirebaseFirestore.instance
          .collection('materialsAtSite')
          .doc(docId)
          .get();

      if (!docSnap.exists ||
          docSnap.data() == null ||
          docSnap.data()!['materials'] == null) {
        setState(() => updateErrorMsg = 'No materials found for selected date');
        return;
      }

      final List<dynamic> mats = docSnap.data()!['materials'];
      updateMaterials = mats.map((e) => Map<String, dynamic>.from(e)).toList();
      updateQuantityControllers = updateMaterials
          .map(
            (mat) => TextEditingController(text: mat['materialQty'].toString()),
          )
          .toList();
    } catch (e) {
      setState(
        () => updateErrorMsg = 'Failed to fetch materials: ${e.toString()}',
      );
    } finally {
      setState(() => isUpdateLoading = false);
    }
  }

  Future<void> updateMaterialQuantity(int index) async {
    if (updateDocId == null) return;

    final newQty = int.tryParse(updateQuantityControllers[index].text.trim());
    if (newQty == null || newQty < 0) {
      _showSnackBar('Please enter a valid quantity', isError: true);
      return;
    }

    try {
      final docRef = FirebaseFirestore.instance
          .collection('materialsAtSite')
          .doc(updateDocId);
      final updatedMaterials = List<Map<String, dynamic>>.from(updateMaterials);
      updatedMaterials[index]['materialQty'] = newQty;

      // Updating entire materials array with the updated quantity of one material
      await docRef.update({'materials': updatedMaterials});

      // Update materialsInventory for this material and site
      final siteId = selectedSiteId ?? '';
      final materialName = updatedMaterials[index]['materialName'] ?? '';

      final invDocRef = FirebaseFirestore.instance
          .collection('materialsInventory')
          .doc(materialName);
      final invDocSnap = await invDocRef.get();

      if (invDocSnap.exists) {
        final data = invDocSnap.data() as Map<String, dynamic>;
        List sites = List.from(data['sites'] ?? []);

        bool siteFound = false;
        for (var s in sites) {
          if (s is Map && s['siteId'] == siteId) {
            s['materialQty'] = newQty;
            siteFound = true;
            break;
          }
        }
        if (!siteFound) {
          sites.add({'siteId': siteId, 'materialQty': newQty});
        }

        await invDocRef.update({
          'sites': sites,
          'lastUpdateOn': FieldValue.serverTimestamp(),
          'materialName': materialName,
        });
      } else {
        await invDocRef.set({
          'comment': '',
          'lastUpdateOn': FieldValue.serverTimestamp(),
          'materialName': materialName,
          'sites': [
            {'siteId': siteId, 'materialQty': newQty},
          ],
        });
      }

      setState(() => updateMaterials[index]['materialQty'] = newQty);
      _showSnackBar('Quantity updated successfully');
    } catch (e) {
      _showSnackBar('Failed to update: ${e.toString()}', isError: true);
    }
  }

  void _addMaterialEntry() {
    final material = selectedMaterial ?? '';
    final unit = selectedUnit ?? '';
    final quantity = int.tryParse(quantityController.text.trim());

    if (material.isEmpty || unit.isEmpty) {
      _showSnackBar('Please select both material and unit', isError: true);
      return;
    }

    if (quantity == null || quantity <= 0) {
      _showSnackBar('Please enter a valid quantity', isError: true);
      return;
    }

    setState(() {
      materialEntries.add({
        'material': material,
        'unit': unit,
        'quantity': quantity,
      });
      quantityController.clear();
    });
  }

  void _deleteMaterialEntry(int index) {
    setState(() => materialEntries.removeAt(index));
    _showSnackBar('Material removed');
  }

  Future<void> _onSave() async {
    if (materialEntries.isEmpty) {
      _showSnackBar('Please add at least one material', isError: true);
      return;
    }

    final siteId = selectedSiteId?.trim() ?? '';
    if (siteId.isEmpty) {
      _showSnackBar('Site ID is required', isError: true);
      return;
    }

    try {
      final materialsArray = materialEntries
          .map(
            (entry) => {
              'materialName': entry['material'],
              'materialQty': entry['quantity'],
              'materialUnit': entry['unit'],
            },
          )
          .toList();

      final docId = '${siteId}_${DateFormat('yyyyMMdd').format(selectedDate)}';
      final docRef = FirebaseFirestore.instance
          .collection('materialsAtSite')
          .doc(docId);
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        await docRef.update({
          'materials': FieldValue.arrayUnion(materialsArray),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        await docRef.set({
          'date': Timestamp.fromDate(selectedDate),
          'materials': materialsArray,
          'siteId': siteId,
          'siteLocation': siteLocationController.text.trim(),
          'supervisorName': supervisorNameController.text.trim(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      // Update materialsInventory collection
      for (final entry in materialsArray) {
        final String materialName = entry['materialName'] ?? '';
        final int materialQty = entry['materialQty'] ?? 0;
        if (materialName.isEmpty) continue;
        final invDocRef = FirebaseFirestore.instance
            .collection('materialsInventory')
            .doc(materialName);
        final invDocSnap = await invDocRef.get();
        final siteObj = {'materialQty': materialQty, 'siteId': siteId};
        if (invDocSnap.exists) {
          final data = invDocSnap.data() as Map<String, dynamic>;
          List sites = (data['sites'] ?? []) as List;
          bool found = false;
          for (var s in sites) {
            if (s is Map && s['siteId'] == siteId) {
              s['materialQty'] = materialQty;
              found = true;
              break;
            }
          }
          if (!found) {
            sites.add(siteObj);
          }
          await invDocRef.update({
            'sites': sites,
            'lastUpdateOn': FieldValue.serverTimestamp(),
            'materialName': materialName,
          });
        } else {
          await invDocRef.set({
            'comment': '',
            'lastUpdateOn': FieldValue.serverTimestamp(),
            'materialName': materialName,
            'sites': [siteObj],
          });
        }
      }

      _showSnackBar('Materials saved successfully');
      setState(() => materialEntries.clear());
    } catch (e) {
      _showSnackBar('Failed to save materials: ${e.toString()}', isError: true);
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ), dialogTheme: DialogThemeData(backgroundColor: Colors.white),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? errorColor : successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SITE INFORMATION',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            _buildSiteIdDropdown(),
            const SizedBox(height: 12),
            _buildReadOnlyField('Site Location', siteLocationController),
            const SizedBox(height: 12),
            _buildReadOnlyField('Supervisor Name', supervisorNameController),
            const SizedBox(height: 12),
            _buildDateField(),
          ],
        ),
      ),
    );
  }

  Widget _buildSiteIdDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Site ID',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: selectedSiteId,
          items: assignedSiteIds
              .map(
                (siteId) => DropdownMenuItem(
                  value: siteId,
                  child: Text(
                    siteId,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
                  ),
                ),
              )
              .toList(),
          onChanged: (val) async {
            setState(() {
              selectedSiteId = val;
              siteIdController.text = val ?? '';
              siteLocationController.clear();
              errorMsg = null;
              updateMaterials.clear();
              updateQuantityControllers.clear();
              updateErrorMsg = null;
            });

            if (val != null) {
              try {
                final snapshot = await FirebaseFirestore.instance
                    .collection('siteSupervisorMap')
                    .where('supervisor', isEqualTo: widget.supervisorName)
                    .where('site', isEqualTo: val)
                    .limit(1)
                    .get();

                if (snapshot.docs.isNotEmpty) {
                  final data = snapshot.docs.first.data();
                  setState(() {
                    siteLocationController.text =
                        data['location']?.toString() ?? '';
                  });
                }
              } catch (e) {
                // Ignore or handle fetch error
              }
              await fetchAvailableUpdateDates();
            }
          },
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        labelStyle: TextStyle(color: Colors.grey.shade600),
      ),
      readOnly: true,
      style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.grey.shade50,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 12),
                Text(
                  DateFormat('MMMM d, yyyy').format(selectedDate),
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMaterialInputCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ADD MATERIALS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            if (dropdownsLoading)
              const Center(child: CircularProgressIndicator())
            else if (materialOptions.isEmpty || unitOptions.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text(
                  'No materials or units available. Please add them in Firestore.',
                  style: TextStyle(color: Colors.orange.shade800),
                ),
              )
            else
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(flex: 3, child: _buildMaterialDropdown()),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: _buildUnitDropdown()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: quantityController,
                          decoration: InputDecoration(
                            labelText: 'Quantity',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            labelStyle: TextStyle(color: Colors.grey.shade600),
                          ),
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _addMaterialEntry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                        child: const Text('ADD'),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Material',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: selectedMaterial,
          items: materialOptions
              .map(
                (mat) => DropdownMenuItem(
                  value: mat,
                  child: Text(
                    mat,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
                  ),
                ),
              )
              .toList(),
          onChanged: (val) => setState(() => selectedMaterial = val),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    );
  }

  Widget _buildUnitDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Unit',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: selectedUnit,
          items: unitOptions
              .map(
                (unit) => DropdownMenuItem(
                  value: unit,
                  child: Text(
                    unit,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
                  ),
                ),
              )
              .toList(),
          onChanged: (val) => setState(() => selectedUnit = val),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    );
  }

  Widget _buildMaterialList() {
    if (materialEntries.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'No materials added yet',
              style: TextStyle(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 8),
            Text(
              'Add materials using the form above',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ADDED MATERIALS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: materialEntries.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final entry = materialEntries[index];
            return Material(
              elevation: 0,
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry['material'],
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${entry['quantity']} ${entry['unit']}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: Colors.red.shade400,
                      ),
                      onPressed: () => _deleteMaterialEntry(index),
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('CANCEL'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('SAVE MATERIALS'),
          ),
        ),
      ],
    );
  }

  Widget _buildUpdateTabContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(),
          const SizedBox(height: 20),
          _buildUpdateDateSelector(),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: fetchMaterialsForUpdate,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('LOAD MATERIALS FOR SELECTED DATE'),
          ),
          const SizedBox(height: 20),
          if (isUpdateLoading)
            const Center(child: CircularProgressIndicator())
          else if (updateErrorMsg != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: errorColor.withOpacity(0.3)),
              ),
              child: Text(updateErrorMsg!, style: TextStyle(color: errorColor)),
            )
          else if (updateMaterials.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UPDATE QUANTITIES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: updateMaterials.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final mat = updateMaterials[index];
                    return Material(
                      elevation: 0,
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mat['materialName'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller:
                                        updateQuantityControllers[index],
                                    decoration: InputDecoration(
                                      labelText: 'Quantity',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                      labelStyle: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: () =>
                                      updateMaterialQuantity(index),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                  ),
                                  child: const Text('UPDATE'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200, width: 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.find_in_page_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No materials loaded',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Load materials for the selected date',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNewEntryTabContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoCard(),
          const SizedBox(height: 20),
          _buildMaterialInputCard(),
          const SizedBox(height: 20),
          _buildMaterialList(),
          const SizedBox(height: 24),
          _buildActionButtons(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: const Text('Material at Site Entry'),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white,
            tabs: const [
              Tab(text: 'New Entry'),
              Tab(text: 'Update Entry'),
            ],
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMsg != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: errorColor),
                      const SizedBox(height: 16),
                      Text(
                        errorMsg!,
                        style: TextStyle(color: errorColor, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: fetchSiteDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            : TabBarView(
                children: [
                  _buildNewEntryTabContent(),
                  _buildUpdateTabContent(),
                ],
              ),
      ),
    );
  }

  @override
  void dispose() {
    siteIdController.dispose();
    siteLocationController.dispose();
    supervisorNameController.dispose();
    quantityController.dispose();
    for (var controller in updateQuantityControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
