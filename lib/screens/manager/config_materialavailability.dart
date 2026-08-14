import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';

class MaterialAvailability extends StatefulWidget {
  const MaterialAvailability({super.key});

  @override
  State<MaterialAvailability> createState() => _MaterialAvailabilityState();
}

class _MaterialAvailabilityState extends State<MaterialAvailability> {
  // Removed unused _firestore field

  String? _selectedMaterial;
  int _count = 0;
  bool _isLoading = false;
  bool _isLoadingMaterials = true;
  bool _isLoadingAvailability = false;
  List<String> _materialNames = [];
  List<Map<String, dynamic>> _availabilityData = [];
  final TextEditingController _countController = TextEditingController();
  final TextEditingController _editCountController = TextEditingController();

  // New state variables for New/Update mode
  bool _isNewMode = true;
  String? _selectedMaterialToUpdate;
  int _existingCount = 0; // To store existing count for update mode

  // New state variables for Update mode checkboxes
  bool _addToExisting = true; // Default to Add mode
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

    // Hide keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      final documentId = _generateDocumentId(_selectedMaterial!);
      final todayDocRef = FirestoreService.getCollection(
        'materialsavailablity',
      ).doc(documentId);

      // Check if document exists for today
      final todayDoc = await todayDocRef.get();

      if (todayDoc.exists) {
        // Document exists, update by summing the counts
        final currentCount = todayDoc.data()!['count'] as int;
        final newCount = currentCount + _count;

        await todayDocRef.update({
          'count': newCount,
          'lastupdated': FieldValue.serverTimestamp(),
        });
      } else {
        // Document doesn't exist, create new one
        await todayDocRef.set({
          'materialName': _selectedMaterial,
          'count': _count,
          'lastupdated': FieldValue.serverTimestamp(),
        });
      }

      _showSuccessDialog('New material added successfully!');
      _resetForm();
      _loadAvailabilityData(); // Refresh the list
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

    // Hide keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      // Find the existing document for today
      final documentId = _generateDocumentId(_selectedMaterialToUpdate!);
      final todayDocRef = FirestoreService.getCollection(
        'materialsavailablity',
      ).doc(documentId);

      // Check if document exists for today
      final todayDoc = await todayDocRef.get();

      if (todayDoc.exists) {
        // Document exists, handle based on checkbox selection
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
        // If no document exists for today, check if there's any existing document for this material
        final existingDocs =
            await FirestoreService.getCollection('materialsavailablity')
                .where('materialName', isEqualTo: _selectedMaterialToUpdate)
                .orderBy('lastupdated', descending: true)
                .limit(1)
                .get();

        if (existingDocs.docs.isNotEmpty) {
          // Update the most recent existing document
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
          // No existing document found, create a new one
          await todayDocRef.set({
            'materialName': _selectedMaterialToUpdate,
            'count': _count,
            'lastupdated': FieldValue.serverTimestamp(),
          });
          _showSuccessDialog('New material entry created successfully!');
        }
      }

      _resetForm();
      _loadAvailabilityData(); // Refresh the list
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

  // New method to get existing count when material is selected in update mode
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
      // First try to get today's document
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

      // If no today's document, get the most recent one
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

  // Handle checkbox changes
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

  Future<void> _updateCount(String documentId, int currentCount) async {
    final newCount = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        _editCountController.text = currentCount.toString();
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            'Edit Count',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _editCountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'New Count',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newCount = int.tryParse(_editCountController.text) ?? 0;
                if (newCount > 0) {
                  Navigator.of(context).pop(newCount);
                } else {
                  _showErrorDialog('Please enter a valid count');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
              ),
              child: const Text('Update', style: TextStyle()),
            ),
          ],
        );
      },
    );

    if (newCount != null && newCount > 0) {
      try {
        await FirestoreService.getCollection(
          'materialsavailablity',
        ).doc(documentId).update({
          'count': newCount,
          'lastupdated': FieldValue.serverTimestamp(),
        });

        _showSuccessDialog('Count updated successfully!');
        _loadAvailabilityData(); // Refresh the list
      } catch (e) {
        _showErrorDialog('Failed to update count: $e');
      }
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
      // Reset checkboxes to default
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
      // Reset checkboxes to default
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
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
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
          content: Text(message, style: const TextStyle(fontSize: 16)),
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
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
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
          content: Text(message, style: const TextStyle(fontSize: 16)),
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
    final Color darkCardBg = AppTheme.getDarkAccent(theme.primaryColor);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    return GlassScaffold(
      padding: EdgeInsets.zero,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Row
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
                    'Material Availability',
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

            // Tab Bar
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
                      onTap: _switchToNewMode,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _isNewMode ? theme.primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'NEW',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: _isNewMode ? Colors.white : const Color(0xFFCBD5E1),
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
                          color: !_isNewMode ? theme.primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'UPDATE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: !_isNewMode ? Colors.white : const Color(0xFFCBD5E1),
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
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
                  child: _isLoadingMaterials
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.primaryColor,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Loading materials...',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          child: _isNewMode
                              ? _buildNewMaterialSection(isMobile, isTablet, isDesktop)
                              : _buildUpdateMaterialSection(isMobile, isTablet, isDesktop),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Mode selection buttons removed — now handled inline in build() tab bar

  Widget _buildNewMaterialSection(
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    final theme = Theme.of(context);
    final Color darkCardBg = AppTheme.getDarkAccent(theme.primaryColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Material Selection Card
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
                      Icons.add_box_rounded,
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
                          'Add New Material',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Select material and enter count to add',
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
              _buildWhiteDropdown(
                label: 'Select Material',
                icon: Icons.inventory_2_rounded,
                value: _selectedMaterial,
                items: _materialNames
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedMaterial = v),
                hintText: 'Choose a material to add',
              ),
              if (_materialNames.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'No materials found. Please add materials to the collection first.',
                  style: TextStyle(
                    color: Colors.orange[300],
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _buildWhiteTextField(
                label: 'Count to Add',
                icon: Icons.pin_rounded,
                hintText: 'Enter count to add',
                controller: _countController,
                keyboardType: TextInputType.number,
                onChanged: (v) => setState(() => _count = int.tryParse(v) ?? 0),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter a number greater than 0',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFFCBD5E1),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Submit Button
        _buildNewSubmitButton(),

        // Info section
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: darkCardBg.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: theme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New Material Logic',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '• If same material exists today, counts will be summed\n'
                      '• Example: Existing 12 + New 12 = Total 24\n'
                      '• Use this for adding new stock to existing materials',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUpdateMaterialSection(
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    final theme = Theme.of(context);
    final Color darkCardBg = AppTheme.getDarkAccent(theme.primaryColor);
    final availableMaterials = _availabilityData
        .map((data) => data['materialName'] as String)
        .toSet()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Material Selection Card
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
                          'Update Material Count',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Modify existing material stock count',
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
              _buildWhiteDropdown(
                label: 'Select Material to Update',
                icon: Icons.inventory_2_rounded,
                value: _selectedMaterialToUpdate,
                items: availableMaterials
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: _onUpdateMaterialSelected,
                hintText: 'Choose a material to update',
              ),
              if (availableMaterials.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'No materials available to update. Please add materials first.',
                  style: TextStyle(color: Colors.orange[300], fontSize: 13),
                ),
              ],

              // Operation type checkboxes
              if (_selectedMaterialToUpdate != null) ...[
                const SizedBox(height: 20),
                const Text(
                  'Operation Type',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
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
                            color: _addToExisting
                                ? theme.primaryColor
                                : Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _addToExisting
                                  ? theme.primaryColor
                                  : Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_circle_outline_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Add',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
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
                            color: _updateExisting
                                ? theme.primaryColor
                                : Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _updateExisting
                                  ? theme.primaryColor
                                  : Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.swap_horiz_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Replace',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
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
              ],

              // Existing count display
              if (_selectedMaterialToUpdate != null && _existingCount > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.primaryColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        color: theme.primaryColor,
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
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$_existingCount units',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: theme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_selectedMaterialToUpdate != null && _existingCount == 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange[300],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No existing count found. This will create a new entry.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange[200],
                          ),
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
                hintText: 'Enter new count',
                controller: _countController,
                keyboardType: TextInputType.number,
                onChanged: (v) => setState(() => _count = int.tryParse(v) ?? 0),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter a number greater than 0',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFFCBD5E1),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Submit Button
        _buildUpdateSubmitButton(),

        // Info section
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: darkCardBg.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: theme.primaryColor,
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
                        color: theme.primaryColor,
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
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // _buildOperationCheckboxes replaced by inline toggle buttons in _buildUpdateMaterialSection

  // Shared white text field helper (matches Material Config style)
  Widget _buildWhiteTextField({
    required String label,
    required IconData icon,
    required String hintText,
    required TextEditingController controller,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
  }) {
    final brandIconColor = AppTheme.getDarkAccent(Theme.of(context).primaryColor);
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
            onChanged: onChanged,
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
                child: Icon(
                  icon,
                  color: brandIconColor,
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
      ],
    );
  }

  // Shared white dropdown helper (matches Material Config style)
  Widget _buildWhiteDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
    IconData icon = Icons.list_alt_rounded,
    String? hintText,
  }) {
    final brandIconColor = AppTheme.getDarkAccent(Theme.of(context).primaryColor);
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
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(16),
            value: (value != null && items.any((i) => i.value == value)) ? value : null,
            style: const TextStyle(
              color: Color(0xFF0A183D),
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: hintText ?? 'Select $label',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Icon(
                  icon,
                  color: brandIconColor,
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
      height: 52,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitNewMaterial,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primaryColor,
          foregroundColor: const Color(0xFF0A183D),
          alignment: Alignment.center,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 6,
          shadowColor: theme.primaryColor.withValues(alpha: 0.4),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0A183D)),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, size: 20, color: Color(0xFF0A183D)),
                  SizedBox(width: 8),
                  Text(
                    'ADD MATERIAL',
                    style: TextStyle(
                      color: Color(0xFF0A183D),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
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
      height: 52,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _updateExistingMaterial,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primaryColor,
          foregroundColor: const Color(0xFF0A183D),
          alignment: Alignment.center,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 6,
          shadowColor: theme.primaryColor.withValues(alpha: 0.4),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0A183D)),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _addToExisting ? Icons.add_rounded : Icons.swap_horiz_rounded,
                    size: 20,
                    color: const Color(0xFF0A183D),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _addToExisting ? 'ADD TO MATERIAL' : 'UPDATE MATERIAL',
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
    );
  }
}
