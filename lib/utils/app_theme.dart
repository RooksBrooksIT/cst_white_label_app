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

  /// Converts a [Color] to a hex string in the format #AARRGGBB.
  static String colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  /// Parses a hex string into a [Color].
  /// Supports formats: #AARRGGBB, #RRGGBB, AARRGGBB, RRGGBB.
  /// Defaults to [defaultColor] if parsing fails.
  static Color hexToColor(String? hex) {
    if (hex == null || hex.isEmpty) return defaultColor;

    String cleanHex = hex.replaceFirst('#', '').toUpperCase();

    try {
      if (cleanHex.length == 6) {
        // Add full opacity if only RRGGBB is provided
        cleanHex = 'FF$cleanHex';
      }

      if (cleanHex.length == 8) {
        return Color(int.parse(cleanHex, radix: 16));
      }
    } catch (e) {
      debugPrint('Error parsing hex color "$hex": $e');
    }

    return defaultColor;
  }

  /// Generates a ThemeData based on the current primary color.
  static ThemeData getTheme(Color primary) {
    // Professional Slate and Navy palette for construction/enterprise
    const Color background = Color(0xFFF8FAFC); // Slate 50
    const Color surface = Colors.white;
    const Color onSurface = Color(0xFF0F172A); // Slate 900
    const Color onSurfaceVariant = Color(0xFF64748B); // Slate 500
    const Color outline = Color(0xFFE2E8F0); // Slate 200

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        onPrimary: getForegroundFor(primary),
        secondary: const Color(0xFF334155), // Slate 700
        onSecondary: Colors.white,
        tertiary: primary.withOpacity(0.8), // Derived tertiary
        onTertiary: getForegroundFor(primary),
        surface: surface,
        onSurface: onSurface,
        surfaceContainerHighest: const Color(0xFFF1F5F9),
        onSurfaceVariant: onSurfaceVariant,
        outline: outline,
        error: const Color(0xFFEF4444), // Red 500
      ),
      scaffoldBackgroundColor: background,
      cardColor: surface,
      dividerColor: outline,
      
      // Modern Typography Hierarchy
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: onSurface, fontWeight: FontWeight.bold, letterSpacing: -1.0),
        headlineMedium: TextStyle(color: onSurface, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        titleLarge: TextStyle(color: onSurface, fontWeight: FontWeight.w600, fontSize: 18),
        bodyLarge: TextStyle(color: onSurface, fontSize: 16),
        bodyMedium: TextStyle(color: onSurfaceVariant, fontSize: 14),
        labelLarge: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.1),
      ),

      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: onSurface, size: 20),
        titleTextStyle: const TextStyle(
          color: onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: outline, width: 1),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: getForegroundFor(primary),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.2),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: getForegroundFor(primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: getForegroundFor(primary),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        prefixIconColor: onSurfaceVariant,
        suffixIconColor: onSurfaceVariant,
        labelStyle: const TextStyle(color: onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      ),
      
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  /// Dummy updateThemeMode for compatibility.
  static Future<void> updateThemeMode(ThemeMode mode) async {}

  /// Returns false as dark mode is now removed.
  static bool isDark(BuildContext context) => false;
}
