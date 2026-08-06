import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import '../widgets/irregular_background.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_text_field.dart';
import '../widgets/glass_button.dart';
import '../utils/enums.dart';

class BrandingEditScreen extends StatefulWidget {
  const BrandingEditScreen({super.key});

  @override
  State<BrandingEditScreen> createState() => _BrandingEditScreenState();
}

class _BrandingEditScreenState extends State<BrandingEditScreen> {
  final TextEditingController _appNameController = TextEditingController();
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

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    try {
      // Re-initialize to ensure org path is fresh
      await FirestoreService.initialize();

      final String appName = _appNameController.text.trim();
      final String colorHex = AppTheme.colorToHex(_selectedColor);

      await FirestoreService.brandingDoc.set({
        'appName': appName,
        'primaryColor': colorHex,
      }, SetOptions(merge: true));

      // Also update the core organization data document (orgName)
      await FirestoreService.orgDataDoc.set({
        'orgName': appName,
      }, SetOptions(merge: true));

      // Update local theme state immediately
      await AppTheme.updateTheme(_selectedColor);
      await AppTheme.updateAppName(appName);

      // Update session data (AuthService) with the new orgName
      await AuthService().updateUserData({'org_name': appName});

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
    

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    if (_isFetching) {
      return GlassScaffold(
        title: 'Branding',
        body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
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
            body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: IrregularBackground(
              color: _selectedColor,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : (isTablet ? 24 : 16),
                  vertical: isDesktop ? 32 : 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'App Customization',
                          style: TextStyle(
                            fontSize: isDesktop ? 32 : 24,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Update your app name, logo, and theme color.',
                          style: TextStyle(
                            color: const Color(0xFF64748B),
                            fontSize: isDesktop ? 16 : 14,
                          ),
                        ),
                        SizedBox(height: isDesktop ? 40 : 32),
                        _buildSection(
                          context,
                          title: 'App Information',
                          icon: Icons.edit_rounded,
                          isDesktop: isDesktop,
                          isTablet: isTablet,
                          child: GlassTextField(
                            controller: _appNameController,
                            label: 'App Name',
                            icon: Icons.app_registration_rounded,
                          ),
                        ),
                        SizedBox(height: isDesktop ? 32 : 24),
                        _buildSection(
                          context,
                          title: 'Brand Color',
                          icon: Icons.palette_rounded,
                          isDesktop: isDesktop,
                          isTablet: isTablet,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: isDesktop ? 16 : 12,
                                runSpacing: isDesktop ? 16 : 12,
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
                                        : () => setState(
                                            () => _selectedColor = c,
                                          ),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isDesktop ? 20 : 16,
                                        vertical: isDesktop ? 12 : 8,
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
                                            width: isDesktop ? 16 : 12,
                                            height: isDesktop ? 16 : 12,
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
                                          SizedBox(width: isDesktop ? 12 : 8),
                                          Text(
                                            opt['label'] as String,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? c
                                                  : const Color(0xFF64748B),
                                              fontSize: isDesktop ? 15 : 13,
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
                        SizedBox(height: isDesktop ? 56 : 48),
                        GlassButton(
                          label: 'SAVE CHANGES',
                          isLoading: _isLoading,
                          onPressed: _saveChanges,
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
        },
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required bool isDesktop,
    required bool isTablet,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: EdgeInsets.all(isDesktop ? 24 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: theme.colorScheme.primary,
                size: isDesktop ? 24 : 20,
              ),
              SizedBox(width: isDesktop ? 16 : 12),
              Text(
                title,
                style: TextStyle(
                  color: const Color(0xFF1E293B),
                  fontSize: isDesktop ? 18 : 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: isDesktop ? 24 : 20),
          child,
        ],
      ),
    );
  }
}
