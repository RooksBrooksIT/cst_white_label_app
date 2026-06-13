import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'pricing_screen.dart';
import '../utils/app_theme.dart';
import '../widgets/glass_scaffold.dart';

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
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    return Theme(
      data: AppTheme.getTheme(_selectedColor),
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final headerColor = const Color(0xFF003668);

          return GlassScaffold(
            title: 'Branding',
            onBack: () => Navigator.pop(context),
            body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 32 : (isTablet ? 24 : 16),
                      vertical: isDesktop ? 24 : 16,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: Column(
                          children: [
                            _buildStepIndicator(theme, isDesktop, isTablet),
                            SizedBox(height: isDesktop ? 32 : 24),
                            // Responsive Branding Content Area (Customization Top, Mockup Bottom)
                            Column(
                              children: [
                                // Top Section: Customization Controls
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isDesktop ? 32 : 24,
                                    vertical: isDesktop ? 40 : 32,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.cardColor,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: theme.dividerColor.withOpacity(
                                        0.2,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'App Personalization',
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                              color:
                                                  theme.colorScheme.onSurface,
                                              letterSpacing: -0.5,
                                              fontSize: isDesktop ? 28 : 24,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Configure your custom app identity and see live changes below.',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontSize: isDesktop ? 16 : 14,
                                            ),
                                      ),
                                      SizedBox(height: isDesktop ? 40 : 32),

                                      // App Section Area
                                      Container(
                                        padding: EdgeInsets.all(
                                          isDesktop ? 28 : 24,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme
                                              .colorScheme
                                              .surfaceVariant
                                              .withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildFieldLabel(
                                              'App Name (Brand Name)',
                                              isDesktop,
                                              isTablet,
                                            ),
                                            const SizedBox(height: 8),
                                            _buildBrandingField(
                                              controller: _appNameController,
                                              hint: widget.orgName,
                                              icon: Icons.edit_note_rounded,
                                              isDesktop: isDesktop,
                                              isTablet: isTablet,
                                            ),
                                            SizedBox(
                                              height: isDesktop ? 32 : 24,
                                            ),
                                            _buildFieldLabel(
                                              'Primary Brand Color',
                                              isDesktop,
                                              isTablet,
                                            ),
                                            SizedBox(
                                              height: isDesktop ? 16 : 12,
                                            ),
                                            _buildColorPalette(
                                              isDesktop,
                                              isTablet,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: isDesktop ? 40 : 32),
                                // Phone Mockup View
                                _buildPhoneMockup(
                                  theme,
                                  screenWidth,
                                  isDesktop,
                                  isTablet,
                                ),
                                SizedBox(height: isDesktop ? 56 : 48),
                                // Navigation
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => Navigator.pop(context),
                                        style: OutlinedButton.styleFrom(
                                          padding: EdgeInsets.symmetric(
                                            vertical: isDesktop ? 20 : 16,
                                          ),
                                          side: BorderSide(
                                            color: theme.dividerColor,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'BACK',
                                          style: TextStyle(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                            fontWeight: FontWeight.bold,
                                            fontSize: isDesktop ? 16 : 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: isDesktop ? 20 : 16),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _isLoading
                                            ? null
                                            : _goToNextStep,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: theme.primaryColor,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(
                                            vertical: isDesktop ? 20 : 16,
                                          ),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                        child: _isLoading
                                            ? SizedBox(
                                                height: isDesktop ? 24 : 20,
                                                width: isDesktop ? 24 : 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : Text(
                                                'CONTINUE',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: isDesktop ? 16 : 14,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: isDesktop ? 48 : 40),
                              ],
                            ),
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
        },
      ),
    );
  }

  Widget _buildPhoneMockup(
    ThemeData theme,
    double screenWidth,
    bool isDesktop,
    bool isTablet,
  ) {
    final String previewName = _appNameController.text.trim().isNotEmpty
        ? _appNameController.text.trim()
        : widget.orgName;

    // Responsive sizing for mockup
    final double mockupWidth = isDesktop ? 280 : (isTablet ? 240 : 200);
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

  Widget _buildStepIndicator(ThemeData theme, bool isDesktop, bool isTablet) {
    const steps = ['Details', 'Branding', 'Pricing'];
    const activeStep = 1;
    final colorScheme = theme.colorScheme;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(steps.length, (index) {
          final isActive = activeStep == index;
          final isDone = activeStep > index;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Step circle and label
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: isDesktop ? 44 : 36,
                    height: isDesktop ? 44 : 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? colorScheme.primary
                          : (isActive
                                ? colorScheme.primary
                                : colorScheme.surfaceVariant),
                    ),
                    child: Center(
                      child: isDone
                          ? Icon(
                              Icons.check,
                              color: Colors.white,
                              size: isDesktop ? 24 : 20,
                            )
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: isActive
                                    ? Colors.white
                                    : colorScheme.onSurfaceVariant,
                                fontSize: isDesktop ? 16 : 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: isDesktop ? 12 : 8),
                  Text(
                    steps[index],
                    style: TextStyle(
                      color: isActive
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      fontSize: isDesktop ? 14 : 12,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              ),
              // Connector line
              if (index < steps.length - 1)
                Container(
                  width: isDesktop ? 60 : 40,
                  height: 2,
                  margin: EdgeInsets.only(
                    bottom: isDesktop ? 30 : 24,
                    left: isDesktop ? 16 : 12,
                    right: isDesktop ? 16 : 12,
                  ),
                  decoration: BoxDecoration(
                    color: activeStep > index
                        ? colorScheme.primary
                        : colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildFieldLabel(String label, bool isDesktop, bool isTablet) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: isDesktop ? 16 : 14,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildBrandingField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDesktop,
    required bool isTablet,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(
          fontSize: isDesktop ? 17 : 15,
          fontWeight: FontWeight.w500,
        ),
        onChanged: (v) => setState(() {}),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            fontSize: isDesktop ? 16 : 14,
          ),
          prefixIcon: Icon(
            icon,
            color: theme.colorScheme.primary,
            size: isDesktop ? 24 : 20,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 20 : 16,
            vertical: isDesktop ? 20 : 16,
          ),
        ),
      ),
    );
  }

  Widget _buildColorPalette(bool isDesktop, bool isTablet) {
    return Wrap(
      spacing: isDesktop ? 16 : 12,
      runSpacing: isDesktop ? 16 : 12,
      children: _colorOptions.map((opt) {
        final isCustom = opt['isCustom'] == true;
        final c = isCustom ? _customColor : opt['color'] as Color;
        final sel = isCustom
            ? (!_colorOptions.any(
                (o) => o['isCustom'] != true && o['color'] == _selectedColor,
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
            width: isDesktop ? 52 : 42,
            height: isDesktop ? 52 : 42,
            decoration: BoxDecoration(
              color: isCustom && !sel ? null : c,
              shape: BoxShape.circle,
              border: Border.all(
                color: sel ? const Color(0xFF1E293B) : Colors.transparent,
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
                        color: c.withOpacity(0.3),
                        blurRadius: isDesktop ? 12 : 8,
                        spreadRadius: isDesktop ? 2 : 1,
                      ),
                    ]
                  : null,
            ),
            child: sel
                ? Icon(
                    Icons.check,
                    color: Colors.white,
                    size: isDesktop ? 24 : 20,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }
}
