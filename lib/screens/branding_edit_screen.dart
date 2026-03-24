import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_text_field.dart';
import '../widgets/glass_button.dart';

class BrandingEditScreen extends StatefulWidget {
  const BrandingEditScreen({super.key});

  @override
  State<BrandingEditScreen> createState() => _BrandingEditScreenState();
}

class _BrandingEditScreenState extends State<BrandingEditScreen> {
  final TextEditingController _appNameController = TextEditingController();
  File? _logoFile;
  bool _isPickingImage = false;
  bool _isLoading = false;
  bool _isFetching = true;
  Color _selectedColor = const Color(0xFF017FDF);
  Color _customColor = const Color(0xFF017FDF);
  String? _orgId;

  final List<Map<String, dynamic>> _colorOptions = [
    {'label': 'Blue', 'color': const Color(0xFF017FDF)},
    {'label': 'Green', 'color': const Color(0xFF00A86B)},
    {'label': 'Purple', 'color': const Color(0xFF7C3AED)},
    {'label': 'Orange', 'color': const Color(0xFFEA580C)},
    {'label': 'Custom', 'isCustom': true},
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentBranding();
  }

  Future<void> _loadCurrentBranding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? dynamicPath = prefs.getString('org_dynamic_path');
      
      if (dynamicPath != null && dynamicPath.isNotEmpty) {
        _orgId = dynamicPath.split('/')[0];
        final doc = await FirebaseFirestore.instance
            .collection(_orgId!)
            .doc('data')
            .collection('admin')
            .doc('User')
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          setState(() {
            _appNameController.text = data['appName'] ?? '';
            final colorHex = data['primaryColor'] as String?;
            if (colorHex != null) {
              _selectedColor = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
              _customColor = _selectedColor;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading branding: $e');
    } finally {
      setState(() => _isFetching = false);
    }
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pick a color'),
          backgroundColor: const Color(0xFF003768),
          titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: _customColor,
              onColorChanged: (color) {
                setState(() => _customColor = color);
              },
              pickerAreaHeightPercent: 0.8,
              enableAlpha: false,
              labelTypes: const [],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('CANCEL', style: TextStyle(color: Colors.white70)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('OK', style: TextStyle(color: Colors.white)),
              onPressed: () {
                setState(() => _selectedColor = _customColor);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickLogo() async {
    if (_isPickingImage) return;
    _isPickingImage = true;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked != null && mounted) {
        setState(() => _logoFile = File(picked.path));
      }
    } catch (e) {
      debugPrint('Image picker error: $e');
    } finally {
      _isPickingImage = false;
    }
  }

  Future<void> _saveChanges() async {
    if (_orgId == null) return;
    setState(() => _isLoading = true);
    try {
      final String appName = _appNameController.text.trim();
      final String colorHex = '#${_selectedColor.value.toRadixString(16).substring(2).toUpperCase()}';

      await FirebaseFirestore.instance
          .collection(_orgId!)
          .doc('data')
          .collection('admin')
          .doc('User')
          .update({
        'appName': appName,
        'primaryColor': colorHex,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Branding updated successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Save error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save changes.'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isFetching) {
      return const GlassScaffold(
        title: 'Branding',
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return GlassScaffold(
      title: 'Branding',
      onBack: () => Navigator.pop(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'App Customization',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Update your app name, logo, and theme color.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 32),
            _buildSection(
              title: 'App Information',
              icon: Icons.edit_rounded,
              child: GlassTextField(
                controller: _appNameController,
                label: 'App Name',
                icon: Icons.app_registration_rounded,
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Company Logo',
              icon: Icons.upload_rounded,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickLogo,
                    child: Container(
                      width: double.infinity,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: _logoFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Image.file(_logoFile!, fit: BoxFit.cover),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined, color: Colors.white30, size: 40),
                                const SizedBox(height: 8),
                                const Text('Change Logo', style: TextStyle(color: Colors.white30)),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Brand Color',
              icon: Icons.palette_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _colorOptions.map((opt) {
                      final isCustom = opt['isCustom'] == true;
                      final c = isCustom ? _customColor : opt['color'] as Color;
                      final isSelected = isCustom
                          ? (!_colorOptions.any((o) => o['isCustom'] != true && o['color'] == _selectedColor))
                          : _selectedColor.value == c.value;

                      return GestureDetector(
                        onTap: isCustom ? _showColorPicker : () => setState(() => _selectedColor = c),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? c.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSelected ? c : Colors.white10, width: 2),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: isCustom && !isSelected ? null : c,
                                  shape: BoxShape.circle,
                                  gradient: isCustom && !isSelected 
                                      ? const SweepGradient(colors: [Colors.red, Colors.blue, Colors.green, Colors.red])
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(opt['label'], style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 13)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            GlassButton(
              label: 'SAVE CHANGES',
              isLoading: _isLoading,
              onPressed: _saveChanges,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required IconData icon, required Widget child}) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue[300], size: 20),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
