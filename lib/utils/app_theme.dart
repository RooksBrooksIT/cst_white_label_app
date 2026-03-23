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

  // ValueNotifier to broadcast theme mode changes (light/dark)
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

    final isDarkMode = prefs.getBool('is_dark_mode') ?? false;
    themeMode.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;
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

  /// Updates the theme mode and persists it to SharedPreferences.
  static Future<void> updateThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    themeMode.notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', mode == ThemeMode.dark);
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

  /// Generates a ThemeData based on the current primary color and mode.
  static ThemeData getTheme(Color primary, {bool isDark = false}) {
    if (isDark) {
      return ThemeData(
        brightness: Brightness.dark,
        primaryColor: primary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          primary: primary,
          onPrimary: getForegroundFor(primary),
          brightness: Brightness.dark,
          surface: const Color(0xFF1E293B),
          onSurface: Colors.white,
          surfaceContainerHighest: const Color(0xFF334155),
          onSurfaceVariant: Colors.white70,
          outline: Colors.white24,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
        dividerColor: Colors.white12,
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: const Color(0xFF1E293B),
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E293B),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E293B),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          prefixIconColor: Colors.white70,
          suffixIconColor: Colors.white70,
          labelStyle: const TextStyle(color: Colors.white70),
          hintStyle: const TextStyle(color: Colors.white38),
        ),
      );
    }

    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        onPrimary: getForegroundFor(primary),
        brightness: Brightness.light,
        surface: Colors.white,
        onSurface: const Color(0xFF1E293B),
        surfaceContainerHighest: const Color(0xFFF1F5F9),
        onSurfaceVariant: const Color(0xFF64748B),
        outline: const Color(0xFFCBD5E1),
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      cardColor: Colors.white,
      dividerColor: const Color(0xFFE2E8F0),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: primary,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        prefixIconColor: const Color(0xFF64748B),
        suffixIconColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(color: Color(0xFF64748B)),
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
  /// Returns true if the current theme is dark.
  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;
}
