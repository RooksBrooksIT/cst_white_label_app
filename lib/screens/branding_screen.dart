import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'pricing_screen.dart';
import '../utils/app_theme.dart';

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

  // Extended color palette
  final List<Map<String, dynamic>> _colorOptions = [
    {'label': 'Blue', 'color': const Color(0xFF017FDF)},
    {'label': 'Green', 'color': const Color(0xFF00A86B)},
    {'label': 'Purple', 'color': const Color(0xFF7C3AED)},
    {'label': 'Orange', 'color': const Color(0xFFEA580C)},
    {'label': 'Teal', 'color': const Color(0xFF008080)},
    {'label': 'Pink', 'color': const Color(0xFFE91E63)},
    {'label': 'Red', 'color': const Color(0xFFDC2626)},
    {'label': 'Indigo', 'color': const Color(0xFF4F46E5)},
    {'label': 'Amber', 'color': const Color(0xFFF59E0B)},
    {'label': 'Cyan', 'color': const Color(0xFF06B6D4)},
    {'label': 'Lime', 'color': const Color(0xFF84CC16)},
    {'label': 'Rose', 'color': const Color(0xFFF43F5E)},
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
      bool isTaken =
          checkResults[1].docs.isNotEmpty || checkResults[2].docs.isNotEmpty;
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
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final isSmallScreen = screenWidth < 600;

    return Theme(
      data: AppTheme.getTheme(_selectedColor),
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final headerColor = const Color(0xFF003668);

          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: AppBar(
              backgroundColor: headerColor,
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: false,
              title: const Text(
                'Branding',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: Colors.white,
                ),
              ),
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: Column(
              children: [
                // Rectangular Header with Step Indicator
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  decoration: BoxDecoration(
                    color: headerColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _buildStepIndicator(theme, headerColor),
                ),

                // Responsive Branding Content Area (Customization Top, Mockup Bottom)
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Top Section: Customization Controls
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 24 : screenWidth * 0.15,
                            vertical: 40,
                          ),
                          decoration: const BoxDecoration(color: Colors.white),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'App Personalization',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF1E293B),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Configure your custom app identity and see live changes below.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 40),

                              // App Section Area
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel('Display Name'),
                                    const SizedBox(height: 8),
                                    _buildProfessionalField(
                                      controller: _appNameController,
                                      hint: widget.orgName,
                                      icon: Icons.edit_rounded,
                                    ),
                                    const SizedBox(height: 32),
                                    _buildFieldLabel('Theme Color'),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Primary: #${_selectedColor.value.toRadixString(16).toUpperCase().substring(2)}',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: Colors.grey[500],
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 16),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: _colorOptions.map((opt) {
                                        final isCustom =
                                            opt['isCustom'] == true;
                                        final c = isCustom
                                            ? _customColor
                                            : opt['color'] as Color;
                                        final sel = isCustom
                                            ? (!_colorOptions.any(
                                                (o) =>
                                                    o['isCustom'] != true &&
                                                    o['color'] ==
                                                        _selectedColor,
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
                                            width: 42,
                                            height: 42,
                                            decoration: BoxDecoration(
                                              color: isCustom && !sel
                                                  ? Colors.transparent
                                                  : c,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: sel
                                                    ? const Color(0xFF1E293B)
                                                    : Colors.transparent,
                                                width: 2.5,
                                              ),
                                              gradient: isCustom && !sel
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
                                              boxShadow: sel
                                                  ? [
                                                      BoxShadow(
                                                        color: c.withOpacity(
                                                          0.3,
                                                        ),
                                                        blurRadius: 8,
                                                        spreadRadius: 1,
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            child: sel
                                                ? const Icon(
                                                    Icons.check,
                                                    color: Colors.white,
                                                    size: 20,
                                                  )
                                                : null,
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Bottom Section: Live Phone Preview
                        Container(
                          width: double.infinity,
                          constraints: BoxConstraints(
                            minHeight: screenHeight * 0.4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9).withOpacity(0.5),
                            border: Border(
                              top: BorderSide(
                                color: const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              _buildPhoneMockup(theme, screenWidth),
                              const SizedBox(height: 48),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen
                                      ? 24
                                      : screenWidth * 0.25,
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _goToNextStep,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F172A),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 20,
                                    ),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    minimumSize: const Size(
                                      double.infinity,
                                      54,
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'PREVIEW PRICING',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.2,
                                          ),
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
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhoneMockup(ThemeData theme, double screenWidth) {
    final String previewName = _appNameController.text.trim().isNotEmpty
        ? _appNameController.text.trim()
        : widget.orgName;

    // Responsive sizing for mockup
    final double mockupWidth = screenWidth < 600 ? 200 : 240;
    final double mockupHeight = mockupWidth * 2;

    // Fixed mockup background (light)
    const Color mockupBackground = Colors.white;
    const Color textColor = Color(0xFF1E293B);
    final Color secondaryTextColor = Colors.grey[600]!;

    return Container(
      width: mockupWidth,
      height: mockupHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFF334155), width: 8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          color: mockupBackground,
          child: Column(
            children: [
              // Mock App Bar
              Container(
                height: mockupHeight * 0.14,
                width: double.infinity,
                color: _selectedColor,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.menu,
                      color: Colors.white,
                      size: mockupWidth * 0.08,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        previewName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: mockupWidth * 0.06,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Mock Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dashboard',
                        style: TextStyle(
                          color: textColor,
                          fontSize: mockupWidth * 0.07,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: mockupHeight * 0.22,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: _selectedColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedColor.withOpacity(0.2),
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.dashboard_rounded,
                            color: _selectedColor,
                            size: mockupWidth * 0.15,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 8,
                        width: 80,
                        decoration: BoxDecoration(
                          color: secondaryTextColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 8,
                        width: 140,
                        decoration: BoxDecoration(
                          color: secondaryTextColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const Spacer(),
                      // Mock Button
                      Container(
                        height: mockupHeight * 0.09,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: _selectedColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'Get Started',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: mockupWidth * 0.045,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: Color(0xFF475569),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildProfessionalField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1E293B),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
        prefixIcon: Icon(icon, color: _selectedColor, size: 18),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _selectedColor, width: 2),
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildStepIndicator(ThemeData theme, Color headerColor) {
    const steps = ['Details', 'Branding', 'Pricing'];
    const activeStep = 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length, (index) {
        final isActive = activeStep == index;
        final isDone = activeStep > index;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? Colors.white
                        : (isActive ? Colors.white : Colors.white24),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: isDone
                        ? Icon(Icons.check, color: headerColor, size: 18)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isActive ? headerColor : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  steps[index],
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white70,
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (index < steps.length - 1)
              Container(
                width: 40,
                height: 2,
                margin: const EdgeInsets.only(bottom: 16, left: 12, right: 12),
                decoration: BoxDecoration(
                  color: activeStep > index ? Colors.white : Colors.white24,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ],
        );
      }),
    );
  }
}
