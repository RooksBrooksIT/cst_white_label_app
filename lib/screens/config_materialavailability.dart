import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';

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
    

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;
    final horizontalPadding = isMobile ? 16.0 : (isTablet ? 24.0 : 32.0);

    return GlassScaffold(
      title: 'Material Availability',
      onBack: () => Navigator.pop(context),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: _isLoadingMaterials
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading materials...',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 24.0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Mode Selection Buttons
                      _buildModeSelectionButtons(isMobile, isTablet, isDesktop),
                      const SizedBox(height: 24),

                      // Add/Update Material Section based on mode
                      _isNewMode
                          ? _buildNewMaterialSection(
                              isMobile,
                              isTablet,
                              isDesktop,
                            )
                          : _buildUpdateMaterialSection(
                              isMobile,
                              isTablet,
                              isDesktop,
                            ),
                    ],
                  ),
                ),
              ),
            ),
        ),
      ),
    );
  }

  Widget _buildModeSelectionButtons(
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    final padding = isMobile ? 12.0 : 16.0;
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _switchToNewMode,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isNewMode
                  ? Theme.of(context).primaryColor
                  : Colors.white,
              foregroundColor: _isNewMode
                  ? Colors.white
                  : Theme.of(context).primaryColor,
              padding: EdgeInsets.symmetric(vertical: padding),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: Theme.of(context).primaryColor,
                  width: _isNewMode ? 0 : 2,
                ),
              ),
              elevation: _isNewMode ? 2 : 0,
            ),
            child: Text(
              'New',
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        SizedBox(width: isMobile ? 12 : 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _switchToUpdateMode,
            style: ElevatedButton.styleFrom(
              backgroundColor: !_isNewMode
                  ? Theme.of(context).primaryColor
                  : Colors.white,
              foregroundColor: !_isNewMode
                  ? Colors.white
                  : Theme.of(context).primaryColor,
              padding: EdgeInsets.symmetric(vertical: padding),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: Theme.of(context).primaryColor,
                  width: !_isNewMode ? 0 : 2,
                ),
              ),
              elevation: !_isNewMode ? 2 : 0,
            ),
            child: Text(
              'Update',
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNewMaterialSection(
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Add New Material',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 16),

        // Material Dropdown for New
        _buildNewMaterialDropdown(),
        const SizedBox(height: 24),

        // Count Input
        _buildCountInput(),
        const SizedBox(height: 32),

        // Submit Button for New
        _buildNewSubmitButton(),

        // Info Section for New
        const SizedBox(height: 32),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).primaryColor.withOpacity(0.7),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'New Material Logic',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '• If same material exists today, counts will be summed\n'
                '• Example: Existing 12 + New 12 = Total 24\n'
                '• Use this for adding new stock to existing materials',
                style: TextStyle(fontSize: 12, height: 1.5),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Update Material Count',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 16),

        // Material Dropdown for Update (only shows existing materials)
        _buildUpdateMaterialDropdown(),
        const SizedBox(height: 24),

        // Operation Type Checkboxes
        if (_selectedMaterialToUpdate != null) _buildOperationCheckboxes(),
        const SizedBox(height: 24),

        // Display existing count
        if (_selectedMaterialToUpdate != null && _existingCount > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Count for "$_selectedMaterialToUpdate"',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_existingCount units',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (_selectedMaterialToUpdate != null && _existingCount == 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_outlined,
                  color: Colors.orange[700],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No existing count found for "$_selectedMaterialToUpdate". This will create a new entry.',
                    style: TextStyle(fontSize: 14, color: Colors.orange[700]),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),

        // Count Input
        _buildCountInput(),
        const SizedBox(height: 32),

        // Submit Button for Update
        _buildUpdateSubmitButton(),

        // Info Section for Update
        const SizedBox(height: 32),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.7),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Update Material Logic',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _addToExisting
                    ? '• Adds the new count to existing count\n'
                          '• Example: Current 22 + Add 22 = Total 44\n'
                          '• Use this for adding more stock to existing materials'
                    : '• Replaces the current count with new value\n'
                          '• Example: Current 22 → Update 44 = Total 44\n'
                          '• Use this for correcting or setting exact counts',
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOperationCheckboxes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Operation Type *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Add Checkbox
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _addToExisting
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _addToExisting
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade300,
                    width: _addToExisting ? 2 : 1,
                  ),
                ),
                child: CheckboxListTile(
                  title: const Text(
                    'Add',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Add to existing count'),
                  value: _addToExisting,
                  onChanged: _onAddToExistingChanged,
                  activeColor: Theme.of(context).colorScheme.primary,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Update Checkbox
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _updateExisting
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _updateExisting
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade300,
                    width: _updateExisting ? 2 : 1,
                  ),
                ),
                child: CheckboxListTile(
                  title: const Text(
                    'Update',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Replace existing count'),
                  value: _updateExisting,
                  onChanged: _onUpdateExistingChanged,
                  activeColor: Theme.of(context).colorScheme.primary,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _addToExisting
              ? 'The entered count will be added to the existing count'
              : 'The existing count will be replaced with the entered count',
          style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _buildNewMaterialDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Select Material *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              value: _selectedMaterial,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                hintText: 'Choose a material to add',
              ),
              hint: const Text(
                'Choose a material to add',
                style: TextStyle(color: Colors.grey),
              ),
              items: _materialNames.map((String material) {
                return DropdownMenuItem<String>(
                  value: material,
                  child: Text(material, style: const TextStyle(fontSize: 16)),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedMaterial = newValue;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a material';
                }
                return null;
              },
              icon: Icon(
                Icons.arrow_drop_down,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        if (_materialNames.isEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'No materials found. Please add materials to the collection first.',
            style: TextStyle(color: Colors.orange[700], fontSize: 14),
          ),
        ],
      ],
    );
  }

  Widget _buildUpdateMaterialDropdown() {
    // Get unique material names from availability data
    final availableMaterials = _availabilityData
        .map((data) => data['materialName'] as String)
        .toSet()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Select Material to Update *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              value: _selectedMaterialToUpdate,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                hintText: 'Choose a material to update',
              ),
              hint: const Text(
                'Choose a material to update',
                style: TextStyle(color: Colors.grey),
              ),
              items: availableMaterials.map((String material) {
                return DropdownMenuItem<String>(
                  value: material,
                  child: Text(material, style: const TextStyle(fontSize: 16)),
                );
              }).toList(),
              onChanged: _onUpdateMaterialSelected,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a material';
                }
                return null;
              },
              icon: Icon(
                Icons.arrow_drop_down,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        if (availableMaterials.isEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'No materials available to update. Please add materials first.',
            style: TextStyle(color: Colors.orange[700], fontSize: 14),
          ),
        ],
      ],
    );
  }

  Widget _buildCountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _isNewMode ? 'Count to Add *' : 'New Count *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: _countController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              hintText: _isNewMode ? 'Enter count to add' : 'Enter new count',
              hintStyle: const TextStyle(color: Colors.grey),
            ),
            style: const TextStyle(fontSize: 16),
            onChanged: (value) {
              setState(() {
                _count = int.tryParse(value) ?? 0;
              });
            },
          ),
        ),
        const SizedBox(height: 4),
        Text('Enter a number greater than 0', style: TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildNewSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitNewMaterial,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 2,
          shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
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
                  Icon(Icons.add, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Add Material',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildUpdateSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _updateExistingMaterial,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 2,
          shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
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
                  Icon(_addToExisting ? Icons.add : Icons.update, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _addToExisting ? 'Add to Material' : 'Update Material',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
