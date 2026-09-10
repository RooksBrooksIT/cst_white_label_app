import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Requests location permission from the user.
  /// Guarantees the system location permission dialog is presented
  /// regardless of whether device GPS service is currently enabled or disabled.
  static Future<bool> handleLocationPermission([BuildContext? context]) async {
    try {
      // 1. Check current permission
      LocationPermission permission = await Geolocator.checkPermission();

      // 2. If denied, request permission directly so the OS prompt appears
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // 3. Handle permanently denied
      if (permission == LocationPermission.deniedForever) {
        debugPrint('LocationService: Location permission is permanently denied.');
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied. Please enable them in app settings.'),
            ),
          );
        }
        return false;
      }

      if (permission == LocationPermission.denied) {
        debugPrint('LocationService: Location permission was denied.');
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are required.')),
          );
        }
        return false;
      }

      // 4. Permission is granted! Now check GPS sensor availability
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('LocationService: Device GPS toggle is currently disabled.');
      }

      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      debugPrint('LocationService: Error handling location permission: $e');
      return false;
    }
  }
}
