import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppTheme {
  // Vibrant Ocean Blue matching screenshot color palette
  static const Color defaultColor = Color(0xFF1E88E5);
  static const Color darkNavyColor = Color(0xFF0B1942);
  static const Color iceBlueColor = Color(0xFFEBF3FA);

  // ValueNotifier to broadcast color changes to the entire app
  static final ValueNotifier<Color> primaryColor = ValueNotifier(defaultColor);

  // Default app name
  static const String defaultAppName = 'eBricks';

  // ValueNotifier to broadcast app name changes
  static final ValueNotifier<String> appName = ValueNotifier(defaultAppName);

  // Dummy ValueNotifier for backward compatibility
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(
    ThemeMode.light,
  );

  /// Displays a modern floating error toast notification matching app theme
  static void showErrorToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        backgroundColor: const Color(0xFF0B1942),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        elevation: 8,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Displays a modern floating success toast notification matching app theme
  static void showSuccessToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: Color(0xFF10B981),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        backgroundColor: const Color(0xFF0B1942),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
        ),
        elevation: 8,
        duration: const Duration(seconds: 4),
      ),
    );
  }

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

  /// Synchronizes branding from Firestore for a given organization.
  static Future<void> syncWithFirestore(String orgId) async {
    try {
      // Use the consistent path from FirestoreService: organisation/{id}/data/branding
      final brandingDoc = await FirebaseFirestore.instance
          .collection('organisation')
          .doc(orgId)
          .collection('data')
          .doc('branding')
          .get();

      DocumentSnapshot<Map<String, dynamic>> finalDoc = brandingDoc;

      if (!brandingDoc.exists) {
        debugPrint(
          'AppTheme: Branding doc not found in data/branding, falling back to root.',
        );
        finalDoc = await FirebaseFirestore.instance
            .collection('organisation')
            .doc(orgId)
            .get();
      }

      if (finalDoc.exists) {
        final data = finalDoc.data()!;
        final String? newAppName = data['appName'] as String?;
        final String? newColorHex = data['primaryColor'] as String?;

        if (newAppName != null && newAppName.isNotEmpty) {
          await updateAppName(newAppName);
        }

        if (newColorHex != null && newColorHex.isNotEmpty) {
          final color = hexToColor(newColorHex);
          await updateTheme(color);
        }

        debugPrint(
          'AppTheme: Successfully synchronized branding from Firestore for $orgId',
        );
      } else {
        debugPrint(
          'AppTheme: No branding document found for $orgId, using defaults.',
        );
      }
    } catch (e) {
      debugPrint('AppTheme: Error syncing with Firestore: $e');
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
    await prefs.setString('org_name', newName);
  }

  /// Updates the global primary color and persists it to SharedPreferences.
  static Future<void> updateTheme(Color newColor) async {
    primaryColor.value = newColor;

    // Explicitly notify listeners to trigger a rebuild
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    primaryColor.notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('brand_color_value', newColor.toARGB32());
  }

  /// Generates a dynamic 4-stop light background gradient based on the selected brand color.
  static List<Color> getBackgroundGradientColors(Color brandColor) {
    final HSLColor hsl = HSLColor.fromColor(brandColor);
    final Color c1 = hsl.withLightness(0.96).withSaturation((hsl.saturation * 0.4).clamp(0.0, 1.0)).toColor();
    final Color c2 = hsl.withLightness(0.82).withSaturation((hsl.saturation * 0.6).clamp(0.0, 1.0)).toColor();
    final Color c3 = hsl.withLightness(0.65).withSaturation((hsl.saturation * 0.75).clamp(0.0, 1.0)).toColor();
    final Color c4 = brandColor;

    return [c1, c2, c3, c4];
  }

  /// Generates a deep dark accent color (e.g. Dark Navy / Dark Forest Green) matching the brand color.
  static Color getDarkAccent(Color brandColor) {
    final HSLColor hsl = HSLColor.fromColor(brandColor);
    return hsl.withLightness(0.12).withSaturation((hsl.saturation * 0.7).clamp(0.0, 1.0)).toColor();
  }

  /// Generates a vibrant high-contrast accent color for icons and text on dark card backgrounds.
  static Color getCardAccent(Color brandColor) {
    final HSLColor hsl = HSLColor.fromColor(brandColor);
    final double lightness = hsl.lightness < 0.65 ? 0.68 : hsl.lightness.clamp(0.65, 0.85);
    return hsl.withLightness(lightness).toColor();
  }

  /// Returns a color (Black or White) that contrasts well with the [background].
  static Color getForegroundFor(Color background) {
    return background.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  /// Converts a [Color] to a hex string in the format #AARRGGBB.
  static String colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
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
    const Color background = Color(0xFFEBF3FA); // Light Ice Blue
    const Color cardBg = Colors.white; // Clean light card background
    const Color onSurface = Color(0xFF0A183D); // Deep Dark Navy Title
    const Color outline = Color(0xFFD4E3F4); // Soft Ice Blue Border

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        onPrimary: getForegroundFor(primary),
        secondary: primary,
        onSecondary: Colors.white,
        tertiary: const Color(0xFF42A5F5),
        onTertiary: Colors.white,
        surface: cardBg,
        onSurface: onSurface,
        surfaceContainerHighest: cardBg,
        onSurfaceVariant: const Color(0xFF475569),
        outline: outline,
        error: const Color(0xFFEF4444),
      ),
      scaffoldBackgroundColor: background,
      cardColor: cardBg,
      dividerColor: const Color(0xFFE2E8F0),

      // Modern Typography Hierarchy
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: onSurface,
          fontWeight: FontWeight.bold,
          letterSpacing: -1.0,
        ),
        headlineMedium: TextStyle(
          color: onSurface,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          color: onSurface,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
        titleMedium: TextStyle(
          color: onSurface,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
        bodyLarge: TextStyle(color: onSurface, fontSize: 16, fontWeight: FontWeight.w700),
        bodyMedium: TextStyle(color: onSurface, fontSize: 14),
        labelLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.1, color: onSurface),
        labelSmall: TextStyle(color: onSurface, fontSize: 11),
      ),

      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: onSurface, size: 20),
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),

      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 3,
        shadowColor: onSurface.withValues(alpha: 0.08),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: onSurface,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: onSurface.withValues(alpha: 0.25),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            letterSpacing: 0.3,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: primary.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            letterSpacing: 0.3,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: onSurface,
          side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: onSurface,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        prefixIconColor: primary,
        suffixIconColor: const Color(0xFF5A759E),
        labelStyle: const TextStyle(
          color: Color(0xFF475569),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.w500),
      ),

      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  /// Dummy updateThemeMode for compatibility.
  static Future<void> updateThemeMode(ThemeMode mode) async {}

  /// Returns false as dark mode is now removed.
  static bool isDark(BuildContext context) => false;
}
