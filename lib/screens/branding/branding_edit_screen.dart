import 'package:demo_cst/services/auth_service.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BrandingEditScreen extends StatefulWidget {
  const BrandingEditScreen({super.key});

  @override
  State<BrandingEditScreen> createState() => _BrandingEditScreenState();
}

class _BrandingEditScreenState extends State<BrandingEditScreen> {
  final TextEditingController _appNameController = TextEditingController();
  bool _isLoading = false;
  bool _isFetching = true;
  Color _selectedColor = const Color(0xFF00A86B);
  Color _customColor = const Color(0xFF00A86B);

  // Extended vibrant color palette options
  final List<Map<String, dynamic>> _colorOptions = [
    {'label': 'Green', 'color': const Color(0xFF00A86B)},
    {'label': 'Ocean Blue', 'color': const Color(0xFF017FDF)},
    {'label': 'Teal Forest', 'color': const Color(0xFF008080)},
    {'label': 'Royal Purple', 'color': const Color(0xFF7C3AED)},
    {'label': 'Vibrant Orange', 'color': const Color(0xFFEA580C)},
    {'label': 'Cyan Wave', 'color': const Color(0xFF06B6D4)},
    {'label': 'Crimson Red', 'color': const Color(0xFFDC2626)},
    {'label': 'Indigo', 'color': const Color(0xFF4F46E5)},
    {'label': 'Amber Gold', 'color': const Color(0xFFF59E0B)},
    {'label': 'Lime Fresh', 'color': const Color(0xFF84CC16)},
    {'label': 'Rose Pink', 'color': const Color(0xFFF43F5E)},
    {'label': 'Deep Violet', 'color': const Color(0xFF9333EA)},
    {'label': 'Midnight Dark', 'color': const Color(0xFF0F172A)},
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
      if (mounted) setState(() => _isFetching = false);
    }
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pick Custom Brand Color'),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _customColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('APPLY COLOR', style: TextStyle(fontWeight: FontWeight.bold)),
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
      await FirestoreService.initialize();

      final String appName = _appNameController.text.trim();
      final String colorHex = AppTheme.colorToHex(_selectedColor);

      await FirestoreService.brandingDoc.set({
        'appName': appName,
        'primaryColor': colorHex,
      }, SetOptions(merge: true));

      await FirestoreService.orgDataDoc.set({
        'orgName': appName,
      }, SetOptions(merge: true));

      await AppTheme.updateTheme(_selectedColor);
      await AppTheme.updateAppName(appName);
      await AuthService().updateUserData({'org_name': appName});

      if (mounted) {
        AppTheme.showSuccessToast(context, 'Branding updated successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Save error: $e');
      if (mounted) {
        AppTheme.showErrorToast(context, 'Failed to save: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _appNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (_isFetching) {
      return GlassScaffold(
        padding: EdgeInsets.zero,
        body: Center(
          child: CircularProgressIndicator(
            color: _selectedColor,
          ),
        ),
      );
    }

    return Theme(
      data: AppTheme.getTheme(_selectedColor),
      child: GlassScaffold(
        padding: EdgeInsets.zero,
        body: SafeArea(
          child: Column(
            children: [
              // Top Header Row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1942),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0B1942).withValues(alpha: 0.25),
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
                    const Text(
                      'Brand Color',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0A183D),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. App Name Container Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                  blurRadius: 14,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: _selectedColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.edit_note_rounded,
                                        color: _selectedColor,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'App Information',
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0A183D),
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Customize your workspace display name.',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  child: Divider(color: Color(0xFFF1F5F9), height: 1),
                                ),
                                const Text(
                                  'App Name',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Theme(
                                  data: Theme.of(context).copyWith(
                                    inputDecorationTheme: const InputDecorationTheme(
                                      filled: false,
                                      fillColor: Colors.transparent,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                                    ),
                                    child: TextField(
                                      controller: _appNameController,
                                      style: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Enter App Name',
                                        hintStyle: const TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        prefixIcon: Padding(
                                          padding: const EdgeInsets.only(right: 10.0),
                                          child: Icon(
                                            Icons.app_registration_rounded,
                                            color: _selectedColor,
                                            size: 20,
                                          ),
                                        ),
                                        prefixIconConstraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                                        border: InputBorder.none,
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // 2. Brand Color Palette Selection Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                  blurRadius: 14,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: _selectedColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.palette_rounded,
                                        color: _selectedColor,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Brand Color Theme',
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0A183D),
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Tap any color to instantly preview the theme.',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  child: Divider(color: Color(0xFFF1F5F9), height: 1),
                                ),
                                _buildColorPalette(),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // 3. Save CTA Button
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveChanges,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _selectedColor,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shadowColor: _selectedColor.withValues(alpha: 0.35),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'SAVE CHANGES',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorPalette() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _colorOptions.map((opt) {
        final isCustom = opt['isCustom'] == true;
        final Color swatchColor = isCustom ? _customColor : opt['color'] as Color;
        final String label = isCustom ? 'Custom' : opt['label'] as String;

        final bool isSelected = isCustom
            ? (!_colorOptions.any(
                (o) => o['isCustom'] != true && o['color'] == _selectedColor,
              ))
            : _selectedColor == swatchColor;

        return GestureDetector(
          onTap: isCustom
              ? _showColorPicker
              : () {
                  setState(() {
                    _selectedColor = swatchColor;
                    _customColor = swatchColor;
                  });
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? _selectedColor : const Color(0xFFE2E8F0),
                width: isSelected ? 1.8 : 1.2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _selectedColor.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: isCustom && !isSelected ? null : swatchColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? _selectedColor : const Color(0xFFCBD5E1),
                      width: 1.2,
                    ),
                    gradient: isCustom && !isSelected
                        ? const SweepGradient(
                            colors: [
                              Colors.red,
                              Colors.orange,
                              Colors.yellow,
                              Colors.green,
                              Colors.blue,
                              Colors.purple,
                              Colors.red,
                            ],
                          )
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 11,
                        )
                      : null,
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
