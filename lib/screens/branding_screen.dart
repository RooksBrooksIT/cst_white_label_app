import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'pricing_screen.dart';
import '../utils/app_theme.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_text_field.dart';
import '../utils/enums.dart';

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
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(
                'OK',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
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

  Future<void> _goToNextStep() async {
    setState(() => _isLoading = true);
    try {
      final String appName = _appNameController.text.trim().isNotEmpty
          ? _appNameController.text.trim()
          : widget.orgName;

      // Check username availability globally across all organizations (new and old) and user subcollections
      final checkResults = await Future.wait([
        FirebaseFirestore.instance
            .collectionGroup('admin')
            .where('username', isEqualTo: widget.username)
            .get(),
        FirebaseFirestore.instance
            .collectionGroup('organizationUser')
            .where('username', isEqualTo: widget.username)
            .limit(1)
            .get(),
        FirebaseFirestore.instance
            .collection('organisation')
            .where('username', isEqualTo: widget.username)
            .limit(1)
            .get(),
      ]);

      // Check if any document named 'data' in the 'admin' collection group matches the username
      bool isTaken = checkResults[1].docs.isNotEmpty || checkResults[2].docs.isNotEmpty;
      if (!isTaken) {
        for (var doc in checkResults[0].docs) {
          if (doc.id == 'data') {
            isTaken = true;
            break;
          }
        }
      }

      if (isTaken) {
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
              selectedColor: _selectedColor,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Navigation error: $e');
      String errorMsg = 'An error occurred. Please try again.';

      if (e.toString().contains('permission-denied')) {
        errorMsg = 'Permission denied. Please check Firestore security rules.';
      } else if (e.toString().contains('index')) {
        errorMsg = 'Firestore index required. Click to copy creation link.';
      } else {
        errorMsg = 'Error: ${e.toString()}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 10),
            action: e.toString().contains('http')
                ? SnackBarAction(
                    label: 'COPY LINK',
                    textColor: Colors.white,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: e.toString()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Error copied to clipboard!'),
                        ),
                      );
                    },
                  )
                : null,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.getTheme(_selectedColor),
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;

          return GlassScaffold(
            title: 'Branding',
            onBack: () => Navigator.pop(context),
            body: Column(
              children: [
                const SizedBox(height: 24),
                // Step Indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildStepIndicator(theme),
                ),
                const SizedBox(height: 12),

                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Customize Branding',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Make your app unique with logo & colors',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 32),

                        // App Information Card
                        GlassCard(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(
                                theme: theme,
                                icon: Icons.grid_view_rounded,
                                title: 'App Information',
                              ),
                              const SizedBox(height: 20),
                              GlassTextField(
                                controller: _appNameController,
                                label: 'App Name',
                                hintText: widget.orgName,
                                icon: Icons.edit_rounded,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        const SizedBox(height: 20),

                        // Color Theme Card
                        GlassCard(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(
                                theme: theme,
                                icon: Icons.palette_rounded,
                                title: 'Color Theme',
                                subtitle:
                                    'Primary Color #${_selectedColor.value.toRadixString(16).toUpperCase().substring(2)}',
                              ),
                              const SizedBox(height: 20),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
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
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: sel
                                            ? c.withOpacity(0.1)
                                            : colorScheme.surface,
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: sel
                                              ? c
                                              : colorScheme.outlineVariant,
                                          width: sel ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isCustom && !sel)
                                            Container(
                                              width: 16,
                                              height: 16,
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
                                              width: 16,
                                              height: 16,
                                              decoration: BoxDecoration(
                                                color: c,
                                                shape: BoxShape.circle,
                                                border: isCustom && sel
                                                    ? null
                                                    : Border.all(
                                                        color: Colors.black12,
                                                      ),
                                              ),
                                            ),
                                          const SizedBox(width: 10),
                                          Text(
                                            opt['label'] as String,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: sel
                                                  ? c
                                                  : colorScheme.onSurface,
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
                            ],
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Next button
                        GlassButton(
                          label: 'NEXT',
                          isLoading: _isLoading,
                          onPressed: _goToNextStep,
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader({
    required ThemeData theme,
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: colorScheme.primary, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepIndicator(ThemeData theme) {
    const steps = ['Details', 'Branding', 'Pricing'];
    const activeStep = 1;
    final primaryColor = theme.primaryColor;
    final colorScheme = theme.colorScheme;

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: activeStep >= i ~/ 2 + 1
                    ? primaryColor
                    : colorScheme.outlineVariant,
              ),
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
                color: done || active ? primaryColor : colorScheme.surface,
                border: Border.all(
                  color: done || active ? primaryColor : colorScheme.outline,
                  width: 2,
                ),
              ),
              child: Center(
                child: done
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : Text(
                        '${idx + 1}',
                        style: TextStyle(
                          color: active
                              ? Colors.white
                              : colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              steps[idx],
              style: theme.textTheme.labelMedium?.copyWith(
                color: active || done
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        );
      }),
    );
  }
}
