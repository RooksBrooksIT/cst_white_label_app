import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:intl/intl.dart';

class MaterialAvailability extends StatefulWidget {
  const MaterialAvailability({super.key});

  @override
  State<MaterialAvailability> createState() => _MaterialAvailabilityState();
}

class _MaterialAvailabilityState extends State<MaterialAvailability> {
  String? _selectedMaterial;
  int _count = 0;
  bool _isLoading = false;
  bool _isLoadingMaterials = true;
  bool _isLoadingAvailability = false;
  List<String> _materialNames = [];
  List<Map<String, dynamic>> _availabilityData = [];
  final TextEditingController _countController = TextEditingController();
  final TextEditingController _editCountController = TextEditingController();

  // Mode variables
  bool _isNewMode = true;
  String? _selectedMaterialToUpdate;
  int _existingCount = 0;

  // Operation mode toggles
  bool _addToExisting = true;
  bool _updateExisting = false;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
    _loadAvailabilityData();
  }

  @override
  void dispose() {
    _countController.dispose();
    _editCountController.dispose();
    super.dispose();
  }

  Future<void> _loadMaterials() async {
    try {
      final querySnapshot = await FirestoreService.getCollection(
        'materials',
      ).limit(100).get();
      if (!mounted) return;
      setState(() {
        _materialNames = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return (data['materialName'] ?? doc.id).toString();
        }).toList();
        _isLoadingMaterials = false;
      });
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Failed to load materials: $e');
      setState(() {
        _isLoadingMaterials = false;
      });
    }
  }

  Future<void> _loadAvailabilityData() async {
    setState(() {
      _isLoadingAvailability = true;
    });
    try {
      final querySnapshot = await FirestoreService.getCollection(
        'materialsavailablity',
      ).orderBy('lastupdated', descending: true).limit(50).get();

      if (!mounted) return;
      setState(() {
        _availabilityData = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'materialName': data['materialName'] ?? '',
            'count': data['count'] ?? 0,
            'lastupdated': data['lastupdated'],
          };
        }).toList();
        _isLoadingAvailability = false;
      });
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Failed to load availability data: $e');
      setState(() {
        _isLoadingAvailability = false;
      });
    }
  }

  String _generateDocumentId(String materialName) {
    final now = DateTime.now();
    final year = now.year;
    final formattedDate =
        '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-$year';
    return '${materialName}_$formattedDate';
  }

  Future<void> _submitNewMaterial() async {
    if (_selectedMaterial == null || _selectedMaterial!.isEmpty) {
      _showErrorDialog('Please select a material');
      return;
    }

    if (_count <= 0) {
      _showErrorDialog('Please enter a valid count (greater than 0)');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      final documentId = _generateDocumentId(_selectedMaterial!);
      final todayDocRef = FirestoreService.getCollection(
        'materialsavailablity',
      ).doc(documentId);

      final todayDoc = await todayDocRef.get();

      if (todayDoc.exists) {
        final currentCount = todayDoc.data()!['count'] as int;
        final newCount = currentCount + _count;

        await todayDocRef.update({
          'count': newCount,
          'lastupdated': FieldValue.serverTimestamp(),
        });
      } else {
        await todayDocRef.set({
          'materialName': _selectedMaterial,
          'count': _count,
          'lastupdated': FieldValue.serverTimestamp(),
        });
      }

      _showSuccessDialog('New material added successfully!');
      _resetForm();
      _loadAvailabilityData();
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Failed to save data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateExistingMaterial() async {
    if (_selectedMaterialToUpdate == null ||
        _selectedMaterialToUpdate!.isEmpty) {
      _showErrorDialog('Please select a material to update');
      return;
    }

    if (_count <= 0) {
      _showErrorDialog('Please enter a valid count (greater than 0)');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      final documentId = _generateDocumentId(_selectedMaterialToUpdate!);
      final todayDocRef = FirestoreService.getCollection(
        'materialsavailablity',
      ).doc(documentId);

      final todayDoc = await todayDocRef.get();

      if (todayDoc.exists) {
        final currentCount = todayDoc.data()!['count'] as int;
        final newCount = _addToExisting ? currentCount + _count : _count;

        await todayDocRef.update({
          'count': newCount,
          'lastupdated': FieldValue.serverTimestamp(),
        });

        _showSuccessDialog(
          _addToExisting
              ? 'Material count added successfully! ($newCount)'
              : 'Material count updated successfully! ($_count)',
        );
      } else {
        final existingDocs =
            await FirestoreService.getCollection('materialsavailablity')
                .where('materialName', isEqualTo: _selectedMaterialToUpdate)
                .orderBy('lastupdated', descending: true)
                .limit(1)
                .get();

        if (existingDocs.docs.isNotEmpty) {
          final existingDoc = existingDocs.docs.first;
          final currentCount = existingDoc.data()['count'] as int;
          final newCount = _addToExisting ? currentCount + _count : _count;

          await FirestoreService.getCollection(
            'materialsavailablity',
          ).doc(existingDoc.id).update({
            'count': newCount,
            'lastupdated': FieldValue.serverTimestamp(),
          });

          _showSuccessDialog(
            _addToExisting
                ? 'Material count added successfully! ($newCount)'
                : 'Material count updated successfully! ($_count)',
          );
        } else {
          await todayDocRef.set({
            'materialName': _selectedMaterialToUpdate,
            'count': _count,
            'lastupdated': FieldValue.serverTimestamp(),
          });
          _showSuccessDialog('New material entry created successfully!');
        }
      }

      _resetForm();
      _loadAvailabilityData();
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Failed to update data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onUpdateMaterialSelected(String? materialName) {
    setState(() {
      _selectedMaterialToUpdate = materialName;
      _existingCount = 0;
      _countController.clear();
    });

    if (materialName != null) {
      _fetchExistingCount(materialName);
    }
  }

  Future<void> _fetchExistingCount(String materialName) async {
    try {
      final documentId = _generateDocumentId(materialName);
      final todayDoc = await FirestoreService.getCollection(
        'materialsavailablity',
      ).doc(documentId).get();

      if (todayDoc.exists) {
        setState(() {
          _existingCount = todayDoc.data()!['count'] as int;
          _countController.text = _existingCount.toString();
          _count = _existingCount;
        });
        return;
      }

      final existingDocs =
          await FirestoreService.getCollection('materialsavailablity')
              .where('materialName', isEqualTo: materialName)
              .orderBy('lastupdated', descending: true)
              .limit(1)
              .get();

      if (existingDocs.docs.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _existingCount = existingDocs.docs.first.data()['count'] as int;
          _countController.text = _existingCount.toString();
          _count = _existingCount;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _existingCount = 0;
          _countController.clear();
        });
      }
    } catch (e) {
      debugPrint('Error fetching existing count: $e');
      if (!mounted) return;
      setState(() {
        _existingCount = 0;
        _countController.clear();
      });
    }
  }

  void _onAddToExistingChanged(bool? value) {
    if (value == true) {
      setState(() {
        _addToExisting = true;
        _updateExisting = false;
      });
    }
  }

  void _onUpdateExistingChanged(bool? value) {
    if (value == true) {
      setState(() {
        _addToExisting = false;
        _updateExisting = true;
      });
    }
  }

  void _switchToNewMode() {
    setState(() {
      _isNewMode = true;
      _selectedMaterialToUpdate = null;
      _selectedMaterial = null;
      _count = 0;
      _existingCount = 0;
      _countController.clear();
      _addToExisting = true;
      _updateExisting = false;
    });
  }

  void _switchToUpdateMode() {
    setState(() {
      _isNewMode = false;
      _selectedMaterial = null;
      _selectedMaterialToUpdate = null;
      _count = 0;
      _existingCount = 0;
      _countController.clear();
      _addToExisting = true;
      _updateExisting = false;
    });
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 24),
              SizedBox(width: 12),
              Text(
                'Success',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          content: Text(message, style: const TextStyle(fontSize: 15)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'OK',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 24),
              SizedBox(width: 12),
              Text(
                'Error',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          content: Text(message, style: const TextStyle(fontSize: 15)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'OK',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _resetForm() {
    setState(() {
      _selectedMaterial = null;
      _selectedMaterialToUpdate = null;
      _count = 0;
      _existingCount = 0;
      _countController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Material Availability',
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
            // Mode Switcher Tabs
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
                      onTap: _switchToNewMode,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _isNewMode ? primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'NEW',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: _isNewMode ? Colors.white : const Color(0xFF0A183D),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: _switchToUpdateMode,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_isNewMode ? primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'UPDATE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: !_isNewMode ? Colors.white : const Color(0xFF0A183D),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
                  child: _isLoadingMaterials
                      ? Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                          ),
                        )
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: _isNewMode
                              ? _buildNewMaterialSection()
                              : _buildUpdateMaterialSection(),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewMaterialSection() {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

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
              const Row(
                children: [
                  Icon(
                    Icons.inventory_2_rounded,
                    color: Color(0xFF3B82F6),
                    size: 24,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Add New Material Availability',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0A183D),
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Record daily material count into company inventory',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),

              // Material Name Dropdown
              _buildWhiteDropdown(
                label: 'Material Name *',
                value: _selectedMaterial,
                icon: Icons.category_rounded,
                hintText: _isLoadingMaterials ? 'Loading materials...' : 'Select material',
                items: _materialNames.map((name) {
                  return DropdownMenuItem<String>(
                    value: name,
                    child: Text(name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedMaterial = value;
                  });
                },
              ),
              const SizedBox(height: 18),

              // Count Field
              _buildWhiteTextField(
                label: 'Available Count *',
                icon: Icons.numbers_rounded,
                hintText: 'Enter available quantity',
                controller: _countController,
                keyboardType: TextInputType.number,
                onChanged: (v) => setState(() => _count = int.tryParse(v) ?? 0),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter a number greater than 0',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _buildNewSubmitButton(),

        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Availability Records',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A183D),
                letterSpacing: -0.3,
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.refresh_rounded,
                color: primaryColor,
                size: 20,
              ),
              onPressed: _loadAvailabilityData,
              tooltip: 'Refresh data',
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildAvailabilityDataList(),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildUpdateMaterialSection() {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

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
                    color: Color(0xFF3B82F6),
                    size: 24,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Update Existing Material',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0A183D),
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Modify stock count or add to existing inventory',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),

              _buildWhiteDropdown(
                label: 'Material Name *',
                value: _selectedMaterialToUpdate,
                icon: Icons.category_rounded,
                hintText: _isLoadingMaterials ? 'Loading materials...' : 'Select material to update',
                items: _materialNames.map((name) {
                  return DropdownMenuItem<String>(
                    value: name,
                    child: Text(name),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    _onUpdateMaterialSelected(value);
                  }
                },
              ),
              const SizedBox(height: 18),

              const Text(
                'Update Operation Mode',
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
                    child: GestureDetector(
                      onTap: () => _onAddToExistingChanged(true),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _addToExisting ? primaryColor : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _addToExisting ? primaryColor : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_circle_outline_rounded,
                              size: 18,
                              color: _addToExisting ? Colors.white : const Color(0xFF0A183D),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Add',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _addToExisting ? Colors.white : const Color(0xFF0A183D),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _onUpdateExistingChanged(true),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _updateExisting ? primaryColor : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _updateExisting ? primaryColor : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.swap_horiz_rounded,
                              size: 18,
                              color: _updateExisting ? Colors.white : const Color(0xFF0A183D),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Replace',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _updateExisting ? Colors.white : const Color(0xFF0A183D),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              if (_selectedMaterialToUpdate != null && _existingCount > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        color: primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current: "$_selectedMaterialToUpdate"',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$_existingCount units',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              _buildWhiteTextField(
                label: 'New Count',
                icon: Icons.pin_rounded,
                hintText: 'Enter count',
                controller: _countController,
                keyboardType: TextInputType.number,
                onChanged: (v) => setState(() => _count = int.tryParse(v) ?? 0),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter a number greater than 0',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _buildUpdateSubmitButton(),

        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: primaryColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Update Material Logic',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _addToExisting
                          ? '• Adds the new count to existing count\n'
                                '• Example: Current 22 + Add 22 = Total 44\n'
                                '• Use this for adding more stock to existing materials'
                          : '• Replaces the current count with new value\n'
                                '• Example: Current 22 → Update 44 = Total 44\n'
                                '• Use this for correcting or setting exact counts',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildAvailabilityDataList() {
    if (_isLoadingAvailability) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_availabilityData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: const Center(
          child: Text(
            'No availability records found.',
            style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _availabilityData.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _availabilityData[index];
        final name = item['materialName']?.toString() ?? 'Unnamed';
        final count = item['count'] ?? 0;
        final ts = item['lastupdated'];
        String dateStr = '';
        if (ts is Timestamp) {
          dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate());
        }

        return Container(
          padding: const EdgeInsets.all(14),
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  color: Color(0xFF3B82F6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0A183D),
                      ),
                    ),
                    if (dateStr.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count units',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWhiteTextField({
    required String label,
    required IconData icon,
    required String hintText,
    required TextEditingController controller,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
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
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            onChanged: onChanged,
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
                child: Icon(
                  icon,
                  color: brandIconColor,
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
      ],
    );
  }

  Widget _buildWhiteDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
    IconData icon = Icons.list_alt_rounded,
    String? hintText,
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
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(14),
            initialValue: (value != null && items.any((i) => i.value == value)) ? value : null,
            style: const TextStyle(
              color: Color(0xFF0A183D),
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: hintText ?? 'Select $label',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Icon(
                  icon,
                  color: brandIconColor,
                  size: 20,
                ),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            items: items,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildNewSubmitButton() {
    final theme = Theme.of(context);
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitNewMaterial,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primaryColor,
          foregroundColor: Colors.white,
          alignment: Alignment.center,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 2,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, size: 20, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'ADD MATERIAL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildUpdateSubmitButton() {
    final theme = Theme.of(context);
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _updateExistingMaterial,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primaryColor,
          foregroundColor: Colors.white,
          alignment: Alignment.center,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 2,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _addToExisting ? Icons.add_rounded : Icons.swap_horiz_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _addToExisting ? 'ADD TO MATERIAL' : 'UPDATE MATERIAL',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
