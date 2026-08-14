import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';

// Custom input formatter for number plate
class NumberPlateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newText = newValue.text.toUpperCase();

    if (newText.isEmpty) {
      return newValue;
    }

    // Remove all non-alphanumeric characters
    String cleanedText = newText.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

    // Apply formatting: TN-00-XX-0000
    final formatted = _formatNumberPlate(cleanedText);

    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatNumberPlate(String text) {
    if (text.isEmpty) return '';

    text = text.toUpperCase();
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      // Add hyphens at specific positions
      if (i == 2 || i == 4 || i == 6) {
        buffer.write('-');
      }
      buffer.write(text[i]);
    }

    return buffer.toString();
  }
}

// Helper function to format number plate
String autoFormatNumberPlate(String input) {
  // Remove all non-alphanumeric characters
  String cleaned = input.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();

  if (cleaned.isEmpty) return '';

  final buffer = StringBuffer();

  for (int i = 0; i < cleaned.length; i++) {
    // Add hyphens at specific positions for TN-00-XX-0000 format
    if (i == 2 || i == 4 || i == 6) {
      buffer.write('-');
    }

    // Ensure proper character types at each position
    if (i < 2) {
      // First 2 characters: Letters (TN)
      buffer.write(cleaned[i]);
    } else if (i < 4) {
      // Next 2 characters: Numbers (00)
      buffer.write(cleaned[i].replaceAll(RegExp(r'[^0-9]'), ''));
    } else if (i < 6) {
      // Next 2 characters: Letters (XX)
      buffer.write(cleaned[i].replaceAll(RegExp(r'[^A-Z]'), ''));
    } else {
      // Remaining characters: Numbers (0000)
      buffer.write(cleaned[i].replaceAll(RegExp(r'[^0-9]'), ''));
    }
  }

  return buffer.toString();
}

class VehicleDetailsPage extends StatefulWidget {
  const VehicleDetailsPage({super.key});

  @override
  State<VehicleDetailsPage> createState() => _VehicleDetailsPageState();
}

class _VehicleDetailsPageState extends State<VehicleDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final _modelNameController = TextEditingController();
  final _numberPlateController = TextEditingController();

  final CollectionReference _vehiclesCollection =
      FirestoreService.getCollection('vehicleDetails');

  String _generatedId = '';
  Vehicle? _submittedVehicle;
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _modelNameController.dispose();
    _numberPlateController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        if (_isEditing && _submittedVehicle != null) {
          // Update existing vehicle in Firestore
          await _vehiclesCollection.doc(_submittedVehicle!.id).update({
            'modelName': _modelNameController.text.trim(),
            'numberPlate': _numberPlateController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Update local state
          Vehicle updatedVehicle = Vehicle(
            id: _submittedVehicle!.id,
            modelName: _modelNameController.text.trim(),
            numberPlate: _numberPlateController.text.trim(),
          );

          setState(() {
            _submittedVehicle = updatedVehicle;
            _isEditing = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Vehicle updated successfully! ID: ${_submittedVehicle!.id}',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          // Create new vehicle in Firestore
          String vehicleId = await _generateVehicleId();
          Vehicle vehicle = Vehicle(
            id: vehicleId,
            modelName: _modelNameController.text.trim(),
            numberPlate: _numberPlateController.text.trim(),
          );

          // Save to Firestore
          await _vehiclesCollection.doc(vehicleId).set({
            'id': vehicleId,
            'modelName': vehicle.modelName,
            'numberPlate': vehicle.numberPlate,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          setState(() {
            _generatedId = vehicleId;
            _submittedVehicle = vehicle;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Vehicle added successfully! ID: $vehicleId'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }

      // Clear form
      _modelNameController.clear();
      _numberPlateController.clear();
    }
  }

  Future<String> _generateVehicleId() async {
    // Get the last vehicle ID from Firestore to continue the sequence
    final QuerySnapshot snapshot = await _vehiclesCollection
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return 'VC001';
    }

    final lastVehicle = snapshot.docs.first;
    final lastId = lastVehicle['id'] as String? ?? 'VC000';

    // Extract number from last ID and increment
    final numberStr = lastId.replaceAll(RegExp(r'[^0-9]'), '');
    final number = (int.tryParse(numberStr) ?? 0) + 1;
    return 'VC${number.toString().padLeft(3, '0')}';
  }

  void _editVehicle() {
    if (_submittedVehicle != null) {
      setState(() {
        _isEditing = true;
        _modelNameController.text = _submittedVehicle!.modelName;
        _numberPlateController.text = _submittedVehicle!.numberPlate;
      });
    }
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _modelNameController.clear();
      _numberPlateController.clear();
    });
  }

  void _deleteVehicle() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Vehicle'),
          content: const Text('Are you sure you want to delete this vehicle?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                setState(() {
                  _isLoading = true;
                });

                try {
                  await _vehiclesCollection.doc(_submittedVehicle!.id).delete();

                  setState(() {
                    _submittedVehicle = null;
                    _generatedId = '';
                    _isEditing = false;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vehicle deleted successfully!'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting vehicle: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } finally {
                  setState(() {
                    _isLoading = false;
                  });
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // Load vehicle data from Firestore (optional - if you want to load existing vehicles)
  Future<void> _loadVehicle(String vehicleId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final doc = await _vehiclesCollection.doc(vehicleId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _submittedVehicle = Vehicle.fromMap(data);
          _generatedId = data['id'];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading vehicle: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 600;

    final primaryColor = Theme.of(context).colorScheme.primary;
    final darkCardBg = AppTheme.getDarkAccent(primaryColor);

    return GlassScaffold(
      title: 'Vehicle Details',
      onBack: () => Navigator.pop(context),
      actions: [
        if (_submittedVehicle != null && !_isEditing)
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Container(
                width: 38,
                height: 38,
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
                    Icons.delete_outline_rounded,
                    color: Color(0xFFF87171),
                    size: 18,
                  ),
                  onPressed: _deleteVehicle,
                  tooltip: 'Delete Vehicle',
                ),
              ),
            ),
          ),
      ],
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Generated ID Display
                    if (_generatedId.isNotEmpty && !_isEditing)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.only(bottom: 20),
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
                            const Text(
                              'Generated Vehicle ID:',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _generatedId,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF22C55E),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Form Container Card
                    Container(
                      padding: const EdgeInsets.all(20),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Vehicle Model Name *',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
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
                                controller: _modelNameController,
                                style: const TextStyle(
                                  color: Color(0xFF0A183D),
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Enter Vehicle Model Name',
                                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.directions_car_rounded,
                                    color: Color(0xFF0A183D),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter vehicle model name';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 16),

                            const Text(
                              'Vehicle Number Plate *',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
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
                                controller: _numberPlateController,
                                style: const TextStyle(
                                  color: Color(0xFF0A183D),
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'TN-00-XX-0000',
                                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.confirmation_number_rounded,
                                    color: Color(0xFF0A183D),
                                  ),
                                ),
                                maxLength: 13,
                                buildCounter: (
                                  context, {
                                  required currentLength,
                                  required isFocused,
                                  required maxLength,
                                }) {
                                  return const Padding(
                                    padding: EdgeInsets.only(top: 6.0),
                                    child: Text(
                                      'Format: TN-00-XX-0000',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFCBD5E1),
                                      ),
                                    ),
                                  );
                                },
                                textInputAction: TextInputAction.done,
                                textCapitalization: TextCapitalization.characters,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[a-zA-Z0-9-]'),
                                  ),
                                  LengthLimitingTextInputFormatter(13),
                                  NumberPlateFormatter(),
                                ],
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter vehicle number plate';
                                  }

                                  final RegExp numberPlateRegex = RegExp(
                                    r'^TN-[0-9]{2}-[A-Z]{2}-[0-9]{4}$',
                                    caseSensitive: false,
                                  );

                                  if (!numberPlateRegex.hasMatch(value)) {
                                    return 'Invalid format. Use: TN-00-XX-0000\nExample: TN-01-AB-1234';
                                  }

                                  return null;
                                },
                                onChanged: (value) {
                                  if (value.isNotEmpty && value.length <= 13) {
                                    final formatted = autoFormatNumberPlate(value);
                                    if (formatted != value) {
                                      WidgetsBinding.instance.addPostFrameCallback((
                                        _,
                                      ) {
                                        _numberPlateController.value =
                                            _numberPlateController.value.copyWith(
                                              text: formatted,
                                              selection: TextSelection.collapsed(
                                                offset: formatted.length,
                                              ),
                                            );
                                      });
                                    }
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Button Row
                            Row(
                              children: [
                                if (_isEditing)
                                  Expanded(
                                    child: SizedBox(
                                      height: 52,
                                      child: OutlinedButton(
                                        onPressed: _cancelEdit,
                                        style: OutlinedButton.styleFrom(
                                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                                          foregroundColor: Colors.white,
                                          side: BorderSide(
                                            color: Colors.white.withValues(alpha: 0.4),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                        ),
                                        child: const Text(
                                          'Cancel',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (_isEditing) const SizedBox(width: 12),
                                Expanded(
                                  child: SizedBox(
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _submitForm,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _isEditing
                                            ? Colors.orangeAccent
                                            : primaryColor,
                                        foregroundColor: const Color(0xFF0A183D),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        elevation: 6,
                                        shadowColor: primaryColor.withValues(alpha: 0.4),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                valueColor:
                                                    AlwaysStoppedAnimation<Color>(
                                                      Color(0xFF0A183D),
                                                    ),
                                              ),
                                            )
                                          : Text(
                                              _isEditing
                                                  ? 'Update Vehicle'
                                                  : 'Submit Vehicle',
                                              style: const TextStyle(
                                                fontSize: 15,
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

                    // Submitted Vehicle Details Card
                    if (_submittedVehicle != null && !_isEditing) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Vehicle Details:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    color: Colors.white,
                                  ),
                                  onPressed: _editVehicle,
                                  tooltip: 'Edit Vehicle',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildDetailRow('Vehicle ID', _submittedVehicle!.id),
                            _buildDetailRow(
                              'Model Name',
                              _submittedVehicle!.modelName,
                            ),
                            _buildDetailRow(
                              'Number Plate',
                              _submittedVehicle!.numberPlate,
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    color: Color(0xFFCBD5E1),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Tap the edit icon to modify vehicle details',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFFCBD5E1),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Edit Mode Indicator
                    if (_isEditing)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(top: 16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.edit_rounded, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Editing Vehicle: ${_submittedVehicle!.id}',
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFFCBD5E1),
              fontSize: 13.5,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontSize: 14.5,
            ),
          ),
        ],
      ),
    );
  }
}

// models/vehicle.dart
class Vehicle {
  final String id;
  final String modelName;
  final String numberPlate;

  Vehicle({
    required this.id,
    required this.modelName,
    required this.numberPlate,
  });

  Map<String, dynamic> toMap() {
    return {'id': id, 'modelName': modelName, 'numberPlate': numberPlate};
  }

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      id: map['id'],
      modelName: map['modelName'],
      numberPlate: map['numberPlate'],
    );
  }
}
