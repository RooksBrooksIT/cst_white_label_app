import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../utils/responsive.dart';
import 'pricing_screen.dart';

class BrandingScreen extends StatefulWidget {
  final String orgName;
  final String email;
  final String phone;
  final String username;
  final String password;
  final String dateStr;

  const BrandingScreen({
    super.key,
    required this.orgName,
    required this.email,
    required this.phone,
    required this.username,
    required this.password,
    required this.dateStr,
  });

  @override
  State<BrandingScreen> createState() => _BrandingScreenState();
}

class _BrandingScreenState extends State<BrandingScreen> {
  final TextEditingController _appNameController = TextEditingController();
  File? _logoFile;
  bool _isPickingImage = false;
  bool _isLoading = false;
  Color _selectedColor = const Color(0xFF017FDF);
  Color _customColor = const Color(0xFF017FDF);

  final List<Map<String, dynamic>> _colorOptions = [
    {'label': 'Blue', 'color': const Color(0xFF017FDF)},
    {'label': 'Green', 'color': const Color(0xFF00A86B)},
    {'label': 'Purple', 'color': const Color(0xFF7C3AED)},
    {'label': 'Orange', 'color': const Color(0xFFEA580C)},
    {'label': 'Custom', 'isCustom': true},
  ];

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pick a color'),
          backgroundColor: Theme.of(context).colorScheme.surface,
          titleTextStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 18,
          ),
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
              child: Text(
                'CANCEL',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('OK', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
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

  @override
  void dispose() {
    _appNameController.dispose();
    super.dispose();
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

  Future<void> _goToNextStep() async {
    setState(() => _isLoading = true);
    try {
      final String appName = _appNameController.text.trim().isNotEmpty
          ? _appNameController.text.trim()
          : widget.orgName;

      // Check username
      final userDoc = await FirebaseFirestore.instance
          .collection('organizationUser')
          .doc(widget.username)
          .get();
      if (userDoc.exists) {
        _showError('Username already taken.');
        setState(() => _isLoading = false);
        return;
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PricingScreen(
              orgName: widget.orgName,
              email: widget.email,
              phone: widget.phone,
              username: widget.username,
              password: widget.password,
              dateStr: widget.dateStr,
              appName: appName,
              logoFile: _logoFile,
              selectedColor: _selectedColor,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Navigation error: $e');
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Branding'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Step Indicator
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.isMobile(context) ? 20 : 40,
              vertical: 8,
            ),
            child: _buildStepIndicator(colorScheme),
          ),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customize Branding',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 26),
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Make your app unique with logo & colors',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 14),
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // App Information Card
                      _buildCard(
                        colorScheme: colorScheme,
                        icon: Icons.grid_view_rounded,
                        iconBgColor: colorScheme.primary.withOpacity(0.1),
                        iconColor: colorScheme.primary,
                        title: 'App Information',
                        child: TextFormField(
                          controller: _appNameController,
                          decoration: const InputDecoration(
                            labelText: 'App Name',
                            prefixIcon: Icon(Icons.edit_rounded),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Company Logo Card
                      _buildCard(
                        colorScheme: colorScheme,
                        icon: Icons.upload_rounded,
                        iconBgColor: colorScheme.secondary.withOpacity(0.1),
                        iconColor: colorScheme.secondary,
                        title: 'Company Logo',
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _pickLogo,
                              child: Container(
                                width: double.infinity,
                                height: 110,
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: colorScheme.outlineVariant,
                                  ),
                                ),
                                child: _logoFile != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(13),
                                        child: Image.file(
                                          _logoFile!,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.cloud_upload_outlined,
                                            size: 36,
                                            color: colorScheme.primary.withOpacity(0.5),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Upload Logo',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                          Text(
                                            'PNG / JPG (5MB)',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _pickLogo,
                                child: const Text('UPLOAD LOGO'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Color Theme Card
                      _buildCard(
                        colorScheme: colorScheme,
                        icon: Icons.palette_rounded,
                        iconBgColor: colorScheme.tertiary.withOpacity(0.1),
                        iconColor: colorScheme.tertiary,
                        title: 'Color Theme',
                        subtitle:
                            'Primary Color  #${_selectedColor.value.toRadixString(16).toUpperCase().substring(2)}',
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _colorOptions.map((opt) {
                            final isCustom = opt['isCustom'] == true;
                            final c = isCustom
                                ? _customColor
                                : opt['color'] as Color;
                            final sel = isCustom
                                ? (!_colorOptions.any(
                                    (o) =>
                                        o['isCustom'] != true &&
                                        o['color'] == _selectedColor,
                                  ))
                                : _selectedColor.value == c.value;

                            return GestureDetector(
                              onTap: isCustom
                                  ? _showColorPicker
                                  : () {
                                      setState(() {
                                        _selectedColor = c;
                                        _customColor = c;
                                      });
                                    },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? c.withOpacity(0.15)
                                      : colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: sel ? c : colorScheme.outlineVariant,
                                    width: sel ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (sel)
                                      Icon(
                                        Icons.check_circle_rounded,
                                        color: c,
                                        size: 16,
                                      )
                                    else if (isCustom)
                                      Container(
                                        width: 14,
                                        height: 14,
                                        decoration: const BoxDecoration(
                                          gradient: SweepGradient(
                                            colors: [
                                              Colors.red,
                                              Colors.orange,
                                              Colors.yellow,
                                              Colors.green,
                                              Colors.blue,
                                              Colors.purple,
                                              Colors.red,
                                            ],
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                      )
                                    else
                                      Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: c,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    const SizedBox(width: 6),
                                    Text(
                                      opt['label'] as String,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: sel ? c : colorScheme.onSurfaceVariant,
                                        fontWeight: sel
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
                      ),
                      const SizedBox(height: 28),

                      // Next (Register) button
                      ElevatedButton(
                        onPressed: _goToNextStep,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('NEXT'),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(ColorScheme colorScheme) {
    const steps = ['Details', 'Branding', 'Pricing'];
    const activeStep = 1; // Always on step 2 here

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(
            child: Container(
              height: 2,
              color: activeStep > i ~/ 2
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
          );
        }
        final idx = i ~/ 2;
        final done = idx < activeStep;
        final active = idx == activeStep;

        return Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done || active
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                border: Border.all(
                  color: done || active
                      ? colorScheme.primary
                      : colorScheme.outline,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: done
                    ? Icon(Icons.check, color: colorScheme.onPrimary, size: 18)
                    : Text(
                        '${idx + 1}',
                        style: TextStyle(
                          color: active ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              steps[idx],
              style: TextStyle(
                fontSize: 11,
                color: active || done ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildCard({
    required ColorScheme colorScheme,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}
