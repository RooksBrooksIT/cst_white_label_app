// pages/vehicle_details_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

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

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _vehiclesCollection = FirebaseFirestore.instance
      .collection('vehicleDetails');

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
    final lastId = lastVehicle['id'] as String;

    // Extract number from last ID and increment
    final number = int.parse(lastId.replaceAll('VC', ''));
    return 'VC${(number + 1).toString().padLeft(3, '0')}';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Details'),
        backgroundColor: Color(0xFF003768),
        foregroundColor: Colors.white,
        actions: [
          if (_submittedVehicle != null && !_isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteVehicle,
              tooltip: 'Delete Vehicle',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Generated ID Display
                  if (_generatedId.isNotEmpty && !_isEditing)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Generated Vehicle ID:',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            _generatedId,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Vehicle Model Name Field
                        TextFormField(
                          controller: _modelNameController,
                          decoration: const InputDecoration(
                            labelText: 'Vehicle Model Name *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.directions_car),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter vehicle model name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Vehicle Number Plate Field with Formatting
                        TextFormField(
                          controller: _numberPlateController,
                          decoration: const InputDecoration(
                            labelText: 'Vehicle Number Plate *',
                            hintText: 'TN-00-XX-0000',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.confirmation_number),
                            counterText: 'Format: TN-00-XX-0000',
                          ),
                          maxLength: 13,
                          buildCounter:
                              (
                                context, {
                                required currentLength,
                                required isFocused,
                                required maxLength,
                              }) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    'Format: TN-00-XX-0000',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
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

                            // Enhanced validation for TN-00-XX-0000 format
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
                            // Additional auto-formatting as user types
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
                        const SizedBox(height: 24),

                        // Button Row
                        Row(
                          children: [
                            if (_isEditing)
                              Expanded(
                                child: SizedBox(
                                  height: 50,
                                  child: OutlinedButton(
                                    onPressed: _cancelEdit,
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                              ),
                            if (_isEditing) const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _submitForm,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isEditing
                                        ? Colors.orange
                                        : Color(0xFF003768),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : Text(
                                          _isEditing
                                              ? 'Update Vehicle'
                                              : 'Submit Vehicle',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Submitted Vehicle Details
                  if (_submittedVehicle != null && !_isEditing)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
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
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Color(0xFF003768),
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
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info,
                                  color: Color(0xFF003768),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Tap the edit icon to modify vehicle details',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF003768),
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

                  // Edit Mode Indicator
                  if (_isEditing)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(top: 16),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.orange[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Editing Vehicle: ${_submittedVehicle!.id}',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
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
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
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
