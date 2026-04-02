import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/firestore_service.dart';
import '../utils/app_theme.dart';
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
      await FirestoreService.initialize();
      final doc = await FirestoreService.brandingDoc.get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _appNameController.text = data['appName'] ?? '';
          _selectedColor = AppTheme.hexToColor(data['primaryColor'] as String?);
          _customColor = _selectedColor;
        });
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
              child: const Text(
                'CANCEL',
                style: TextStyle(color: Colors.white70),
              ),
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
    setState(() => _isLoading = true);
    try {
      // Re-initialize to ensure org path is fresh
      await FirestoreService.initialize();

      final String appName = _appNameController.text.trim();
      final String colorHex = AppTheme.colorToHex(_selectedColor);

      String? logoUrl;
      if (_logoFile != null) {
        final String orgId = FirestoreService.currentOrgId;
        final ref = FirebaseStorage.instance.ref().child('org_logos/$orgId.jpg');
        await ref.putFile(_logoFile!);
        logoUrl = await ref.getDownloadURL();
      }

      await FirestoreService.brandingDoc.set({
        'appName': appName,
        'primaryColor': colorHex,
        if (logoUrl != null) 'logoUrl': logoUrl,
      }, SetOptions(merge: true));

      // Update local theme state immediately
      await AppTheme.updateTheme(_selectedColor);
      await AppTheme.updateAppName(appName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Branding updated successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isFetching) {
      return const GlassScaffold(
        title: 'Branding',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Theme(
      data: AppTheme.getTheme(_selectedColor),
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;

          return GlassScaffold(
            title: 'Branding',
            onBack: () => Navigator.pop(context),
            appBarBackgroundColor: colorScheme.primary,
            appBarForegroundColor: colorScheme.onPrimary,
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
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Update your app name, logo, and theme color.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  _buildSection(
                    context,
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
                    context,
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
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: _logoFile != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: Image.file(
                                      _logoFile!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate_outlined,
                                        color: const Color(0xFF94A3B8),
                                        size: 40,
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Change Logo',
                                        style: TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSection(
                    context,
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
                            final c = isCustom
                                ? _customColor
                                : opt['color'] as Color;
                            final isSelected = isCustom
                                ? (!_colorOptions.any(
                                    (o) =>
                                        o['isCustom'] != true &&
                                        o['color'] == _selectedColor,
                                  ))
                                : _selectedColor.value == c.value;

                            return GestureDetector(
                              onTap: isCustom
                                  ? _showColorPicker
                                  : () => setState(() => _selectedColor = c),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? c.withOpacity(0.1)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? c
                                        : const Color(0xFFE2E8F0),
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: isCustom && !isSelected
                                            ? null
                                            : c,
                                        shape: BoxShape.circle,
                                        gradient: isCustom && !isSelected
                                            ? const SweepGradient(
                                                colors: [
                                                  Colors.red,
                                                  Colors.blue,
                                                  Colors.green,
                                                  Colors.red,
                                                ],
                                              )
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      opt['label'] as String,
                                      style: TextStyle(
                                        color: isSelected
                                            ? c
                                            : const Color(0xFF64748B),
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
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
        },
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
