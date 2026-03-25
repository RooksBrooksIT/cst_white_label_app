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

  /// Returns a translucent version of the primary color for glass effects.
  static Color getGlassColor(BuildContext context, {double opacity = 0.1}) {
    return primaryColor.value.withOpacity(opacity);
  }

  /// Returns a white or black overlay color based on brightness.
  static Color getOverlayColor(BuildContext context, {double opacity = 0.1}) {
    return isDark(context) ? Colors.white.withOpacity(opacity) : Colors.black.withOpacity(opacity);
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
          secondary: Color.lerp(primary, Colors.white, 0.2)!,
          onSecondary: Colors.white,
          brightness: Brightness.dark,
          surface: const Color(0xFF0F172A),
          onSurface: Colors.white,
          surfaceContainerHighest: const Color(0xFF1E293B),
          onSurfaceVariant: Colors.white70,
          outline: Colors.white24,
          error: Colors.redAccent,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
        dividerColor: Colors.white12,
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.transparent,
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
            foregroundColor: getForegroundFor(primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: getForegroundFor(primary),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E293B),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white10)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primary, width: 1.5)),
          prefixIconColor: Colors.white70,
          suffixIconColor: Colors.white70,
          labelStyle: const TextStyle(color: Colors.white70),
          hintStyle: const TextStyle(color: Colors.white38),
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: primary,
          selectionColor: primary.withOpacity(0.3),
          selectionHandleColor: primary,
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
        secondary: Color.lerp(primary, Colors.black, 0.2)!,
        onSecondary: Colors.white,
        brightness: Brightness.light,
        surface: const Color(0xFFF8FAFC),
        onSurface: const Color(0xFF0F172A),
        surfaceContainerHighest: Colors.white,
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
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        titleTextStyle: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: getForegroundFor(primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: getForegroundFor(primary),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.black.withOpacity(0.03),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primary, width: 1.5)),
        prefixIconColor: const Color(0xFF64748B),
        suffixIconColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(color: Color(0xFF64748B)),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: primary.withOpacity(0.3),
        selectionHandleColor: primary,
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
  /// Returns true if the current theme is dark.
  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;
}
