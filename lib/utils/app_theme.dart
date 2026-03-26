import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  // Default primary color matching the current app theme
  static const Color defaultColor = Color(0xFF003768);
  
  // ValueNotifier to broadcast color changes to the entire app
  static final ValueNotifier<Color> primaryColor = ValueNotifier(defaultColor);

  // Default app name
  static const String defaultAppName = 'CONSTRUCT PRO';

  // ValueNotifier to broadcast app name changes
  static final ValueNotifier<String> appName = ValueNotifier(defaultAppName);

  // Dummy ValueNotifier for backward compatibility
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.light);

  /// Initializes the theme by loading the stored brand color and app name from SharedPreferences.
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final colorVal = prefs.getInt('brand_color_value');
    if (colorVal != null) {
      primaryColor.value = Color(colorVal);
    }
    
    final storedAppName = prefs.getString('app_name');
    if (storedAppName != null && storedAppName.isNotEmpty) {
      appName.value = storedAppName;
    }
  }

  /// Updates the global app name and persists it to SharedPreferences.
  static Future<void> updateAppName(String newName) async {
    appName.value = newName;
    
    // Explicitly notify listeners
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    appName.notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_name', newName);
  }

  /// Updates the global primary color and persists it to SharedPreferences.
  static Future<void> updateTheme(Color newColor) async {
    primaryColor.value = newColor;
    
    // Explicitly notify listeners to trigger a rebuild
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    primaryColor.notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('brand_color_value', newColor.value);
  }

  /// Returns a color (Black or White) that contrasts well with the [background].
  static Color getForegroundFor(Color background) {
    return background.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  /// Generates a ThemeData based on the current primary color.
  static ThemeData getTheme(Color primary) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        onPrimary: getForegroundFor(primary),
        secondary: Color.lerp(primary, Colors.black, 0.2)!,
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: const Color(0xFF1E293B),
        surfaceContainerHighest: const Color(0xFFF1F5F9),
        onSurfaceVariant: const Color(0xFF64748B),
        outline: const Color(0xFFE2E8F0),
        error: Colors.red[700],
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      cardColor: Colors.white,
      dividerColor: const Color(0xFFE2E8F0),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        titleTextStyle: const TextStyle(
          color: Color(0xFF1E293B),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: getForegroundFor(primary),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: getForegroundFor(primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: getForegroundFor(primary),
        elevation: 4,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        prefixIconColor: const Color(0xFF64748B),
        suffixIconColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: primary.withOpacity(0.3),
        selectionHandleColor: primary,
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  /// Dummy updateThemeMode for compatibility.
  static Future<void> updateThemeMode(ThemeMode mode) async {}

  /// Returns false as dark mode is now removed.
  static bool isDark(BuildContext context) => false;
}
