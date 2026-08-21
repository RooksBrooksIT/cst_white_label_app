import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/utils/responsive.dart';

class NumberPlateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newText = newValue.text.toUpperCase();
    if (newText.isEmpty) return newValue;

    String cleanedText = newText.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
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
      if (i == 2 || i == 4 || i == 6) {
        buffer.write('-');
      }
      buffer.write(text[i]);
    }
    return buffer.toString();
  }
}

String autoFormatNumberPlate(String input) {
  String cleaned = input.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
  if (cleaned.isEmpty) return '';

  final buffer = StringBuffer();
  for (int i = 0; i < cleaned.length; i++) {
    if (i == 2 || i == 4 || i == 6) {
      buffer.write('-');
    }
    if (i < 2) {
      buffer.write(cleaned[i]);
    } else if (i < 4) {
      buffer.write(cleaned[i].replaceAll(RegExp(r'[^0-9]'), ''));
    } else if (i < 6) {
      buffer.write(cleaned[i].replaceAll(RegExp(r'[^A-Z]'), ''));
    } else {
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
  final _searchController = TextEditingController();

  final CollectionReference _vehiclesCollection =
      FirestoreService.getCollection('vehicleDetails');

  String? _editingVehicleId;
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _modelNameController.dispose();
    _numberPlateController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<String> _generateVehicleId() async {
    final QuerySnapshot snapshot = await _vehiclesCollection
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return 'VC001';
    }

    final lastVehicle = snapshot.docs.first;
    final lastId = (lastVehicle.data() as Map<String, dynamic>)['id'] as String? ?? 'VC000';
    final numberStr = lastId.replaceAll(RegExp(r'[^0-9]'), '');
    final number = (int.tryParse(numberStr) ?? 0) + 1;
    return 'VC${number.toString().padLeft(3, '0')}';
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_editingVehicleId != null) {
        await _vehiclesCollection.doc(_editingVehicleId).update({
          'modelName': _modelNameController.text.trim(),
          'numberPlate': _numberPlateController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vehicle updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        String vehicleId = await _generateVehicleId();
        await _vehiclesCollection.doc(vehicleId).set({
          'id': vehicleId,
          'modelName': _modelNameController.text.trim(),
          'numberPlate': _numberPlateController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Vehicle added successfully! ID: $vehicleId'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      _resetForm();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _editVehicle(Map<String, dynamic> data) {
    setState(() {
      _editingVehicleId = data['id'];
      _modelNameController.text = data['modelName'] ?? '';
      _numberPlateController.text = data['numberPlate'] ?? '';
    });
  }

  void _resetForm() {
    setState(() {
      _editingVehicleId = null;
      _modelNameController.clear();
      _numberPlateController.clear();
    });
  }

  void _deleteVehicle(String vehicleId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete Vehicle', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete vehicle $vehicleId?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.of(context).pop();
                setState(() => _isLoading = true);
                try {
                  await _vehiclesCollection.doc(vehicleId).delete();
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Vehicle deleted successfully!'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Error deleting vehicle: $e')),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    final primaryColor = Theme.of(context).primaryColor;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Vehicle Details',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
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
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 650),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormCard(primaryColor),
                  const SizedBox(height: 20),
                  _buildSearchAndListHeader(primaryColor),
                  const SizedBox(height: 12),
                  _buildVehicleListStream(primaryColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _editingVehicleId != null ? Icons.edit_rounded : Icons.add_to_photos_rounded,
                    size: 18,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _editingVehicleId != null
                      ? 'Edit Vehicle ($_editingVehicleId)'
                      : 'Register New Vehicle',
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0A183D),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildCustomTextField(
              label: 'Vehicle Model Name *',
              child: TextFormField(
                controller: _modelNameController,
                style: const TextStyle(color: Color(0xFF0A183D), fontSize: 14.5, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  hintText: 'e.g. Tata Prima / Ashok Leyland',
                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  prefixIcon: Icon(Icons.directions_car_rounded, color: Color(0xFF64748B), size: 20),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter model name' : null,
              ),
            ),
            const SizedBox(height: 14),
            _buildCustomTextField(
              label: 'Vehicle Number Plate *',
              child: TextFormField(
                controller: _numberPlateController,
                style: const TextStyle(color: Color(0xFF0A183D), fontSize: 14.5, fontWeight: FontWeight.w700),
                maxLength: 13,
                buildCounter: (ctx, {required currentLength, required isFocused, required maxLength}) {
                  return const SizedBox.shrink();
                },
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9-]')),
                  LengthLimitingTextInputFormatter(13),
                  NumberPlateFormatter(),
                ],
                decoration: const InputDecoration(
                  hintText: 'TN-00-XX-0000',
                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  prefixIcon: Icon(Icons.confirmation_number_rounded, color: Color(0xFF64748B), size: 20),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter vehicle number plate';
                  }
                  final RegExp numberPlateRegex = RegExp(
                    r'^TN-[0-9]{2}-[A-Z]{2}-[0-9]{4}$',
                    caseSensitive: false,
                  );
                  if (!numberPlateRegex.hasMatch(value)) {
                    return 'Format must be TN-00-XX-0000';
                  }
                  return null;
                },
                onChanged: (value) {
                  if (value.isNotEmpty && value.length <= 13) {
                    final formatted = autoFormatNumberPlate(value);
                    if (formatted != value) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _numberPlateController.value = _numberPlateController.value.copyWith(
                          text: formatted,
                          selection: TextSelection.collapsed(offset: formatted.length),
                        );
                      });
                    }
                  }
                },
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                if (_editingVehicleId != null) ...[
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _resetForm,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              _editingVehicleId != null ? 'UPDATE VEHICLE' : 'SAVE VEHICLE',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTextField({required String label, required Widget child}) {
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
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildSearchAndListHeader(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Fleet Directory',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A183D),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            style: const TextStyle(color: Color(0xFF0A183D), fontSize: 13.5, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Search vehicle model or number plate...',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search_rounded, color: primaryColor, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleListStream(Color primaryColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: _vehiclesCollection.orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];

        final filtered = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final model = (data['modelName'] ?? '').toString().toLowerCase();
          final plate = (data['numberPlate'] ?? '').toString().toLowerCase();
          final id = (data['id'] ?? doc.id).toString().toLowerCase();
          return model.contains(_searchQuery) ||
              plate.contains(_searchQuery) ||
              id.contains(_searchQuery);
        }).toList();

        if (filtered.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: const Center(
              child: Text(
                'No vehicle records found.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final data = filtered[index].data() as Map<String, dynamic>;
            final vehicleId = data['id'] ?? filtered[index].id;
            final modelName = data['modelName'] ?? 'Vehicle';
            final numberPlate = data['numberPlate'] ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
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
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.local_shipping_rounded, color: primaryColor, size: 20),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        modelName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Color(0xFF0A183D),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        vehicleId,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  numberPlate,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF2563EB)),
                      onPressed: () => _editVehicle(data),
                      tooltip: 'Edit Vehicle',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                      onPressed: () => _deleteVehicle(vehicleId),
                      tooltip: 'Delete Vehicle',
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
