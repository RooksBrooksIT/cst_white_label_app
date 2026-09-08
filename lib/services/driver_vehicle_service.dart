import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ebricks/services/firestore_service.dart';

/// Exception thrown when a vehicle is already assigned to another driver.
class VehicleAssignmentException implements Exception {
  final String message;
  VehicleAssignmentException(this.message);

  @override
  String toString() => message;
}

class DriverVehicleService {
  static CollectionReference<Map<String, dynamic>> get _driversCol =>
      FirestoreService.getCollection('drivers');

  static CollectionReference<Map<String, dynamic>> get _vehiclesCol =>
      FirestoreService.getCollection('vehicleDetails');

  static CollectionReference<Map<String, dynamic>> get _assignmentsCol =>
      FirestoreService.getCollection('vehicle_assignments');

  /// Streams available vehicles for assignment.
  /// If [currentDriverId] is provided (e.g. while editing), the vehicle already
  /// assigned to this driver is also included in the stream.
  static Stream<List<Map<String, dynamic>>> streamAvailableVehicles({
    String? currentDriverId,
  }) {
    return _vehiclesCol.snapshots().map((snapshot) {
      final list = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final vehicleId = data['id'] as String? ?? doc.id;
        final modelName = data['modelName'] as String? ?? '';
        final numberPlate = data['numberPlate'] as String? ?? '';
        final isAssigned = data['isAssigned'] as bool? ?? false;
        final assignedDriverId = data['assignedDriverId'] as String?;
        final assignedDriverName = data['assignedDriverName'] as String?;

        // Vehicle is available if unassigned OR already assigned to the current driver
        final bool isCurrentDriverAssigned =
            currentDriverId != null &&
            currentDriverId.isNotEmpty &&
            assignedDriverId == currentDriverId;

        final bool isAvailable = !isAssigned || isCurrentDriverAssigned;

        if (isAvailable) {
          list.add({
            'id': vehicleId,
            'modelName': modelName,
            'numberPlate': numberPlate,
            'isAssigned': isAssigned,
            'assignedDriverId': assignedDriverId,
            'assignedDriverName': assignedDriverName,
            'isCurrentDriverAssigned': isCurrentDriverAssigned,
          });
        }
      }

      list.sort((a, b) {
        final nameA = (a['modelName'] as String? ?? '').toLowerCase();
        final nameB = (b['modelName'] as String? ?? '').toLowerCase();
        return nameA.compareTo(nameB);
      });

      return list;
    });
  }

  /// Generates the next sequential Driver ID (e.g., DV001, DV002).
  static Future<String> getNextDriverId() async {
    final snapshot = await _driversCol
        .orderBy('driverId', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return 'DV001';

    final lastDriverId = snapshot.docs.first['driverId'] as String? ?? 'DV000';
    final numberStr = lastDriverId.replaceAll(RegExp(r'[^0-9]'), '');
    final number = int.tryParse(numberStr) ?? 0;
    return 'DV${(number + 1).toString().padLeft(3, '0')}';
  }

  /// Atomically creates or updates a driver with vehicle assignment.
  /// Enforces:
  /// - Backend uniqueness check on [newVehicleId] via transaction.
  /// - Automatic release of the driver's previous vehicle if changed.
  /// - Release of vehicle if driver status is changed to 'Inactive'.
  /// - Atomic updates across `drivers`, `vehicleDetails`, and `vehicle_assignments`.
  static Future<void> saveDriverWithAssignment({
    required String driverId,
    required String driverName,
    required String driverPhone,
    required String driverAddress,
    required String driverLicense,
    required String experience,
    required String status,
    String? newVehicleId,
    String? newVehicleModel,
    String? newVehiclePlate,
    bool isEditing = false,
  }) async {
    await FirestoreService.runTransaction((transaction) async {
      // 1. Read current driver document
      final driverRef = _driversCol.doc(driverId);
      final driverSnap = await transaction.get(driverRef);
      final oldVehicleId = driverSnap.exists
          ? (driverSnap.data()?['assignedVehicleId'] as String?)
          : null;

      // Inactive drivers must not hold active vehicle assignments
      final bool isInactive = status.trim().toLowerCase() == 'inactive';
      final String? targetVehicleId = isInactive ? null : (newVehicleId?.trim().isEmpty ?? true ? null : newVehicleId?.trim());

      // 2. Read new vehicle and assignment lock documents if assigning
      DocumentReference<Map<String, dynamic>>? newVehicleRef;
      DocumentReference<Map<String, dynamic>>? newAssignRef;
      DocumentSnapshot<Map<String, dynamic>>? newVehicleSnap;
      DocumentSnapshot<Map<String, dynamic>>? newAssignSnap;

      if (targetVehicleId != null) {
        newVehicleRef = _vehiclesCol.doc(targetVehicleId);
        newAssignRef = _assignmentsCol.doc(targetVehicleId);
        newVehicleSnap = await transaction.get(newVehicleRef);
        newAssignSnap = await transaction.get(newAssignRef);

        // Backend duplicate validation: check lock collection
        if (newAssignSnap.exists) {
          final assignedDriver = newAssignSnap.data()?['driverId'] as String?;
          if (assignedDriver != null &&
              assignedDriver.isNotEmpty &&
              assignedDriver != driverId) {
            final otherName =
                newAssignSnap.data()?['driverName'] ?? 'another driver';
            throw VehicleAssignmentException(
              'Vehicle $targetVehicleId is already assigned to $otherName ($assignedDriver). Duplicate assignment is prohibited.',
            );
          }
        }

        // Backend duplicate validation: check vehicleDetails document
        if (newVehicleSnap.exists) {
          final assignedDriver =
              newVehicleSnap.data()?['assignedDriverId'] as String?;
          if (assignedDriver != null &&
              assignedDriver.isNotEmpty &&
              assignedDriver != driverId) {
            final otherName =
                newVehicleSnap.data()?['assignedDriverName'] ?? 'another driver';
            throw VehicleAssignmentException(
              'Vehicle $targetVehicleId is already assigned to $otherName ($assignedDriver). Duplicate assignment is prohibited.',
            );
          }
        }
      }

      // 3. Read previous vehicle document and assignment lock if releasing/reassigning
      DocumentReference<Map<String, dynamic>>? oldVehicleRef;
      DocumentReference<Map<String, dynamic>>? oldAssignRef;

      if (oldVehicleId != null &&
          oldVehicleId.isNotEmpty &&
          oldVehicleId != targetVehicleId) {
        oldVehicleRef = _vehiclesCol.doc(oldVehicleId);
        oldAssignRef = _assignmentsCol.doc(oldVehicleId);
        // All transaction reads must be executed before writes
        await transaction.get(oldVehicleRef);
        await transaction.get(oldAssignRef);
      }

      // --- WRITES ---

      // Step A: Release old vehicle if assigned and changing
      if (oldVehicleRef != null && oldAssignRef != null) {
        transaction.update(oldVehicleRef, {
          'isAssigned': false,
          'assignedDriverId': null,
          'assignedDriverName': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.delete(oldAssignRef);
      }

      // Step B: Assign new vehicle if targetVehicleId is specified
      if (targetVehicleId != null &&
          newVehicleRef != null &&
          newAssignRef != null) {
        transaction.set(
          newAssignRef,
          {
            'vehicleId': targetVehicleId,
            'driverId': driverId,
            'driverName': driverName,
            'assignedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        transaction.update(newVehicleRef, {
          'isAssigned': true,
          'assignedDriverId': driverId,
          'assignedDriverName': driverName,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Step C: Update or create driver document
      final Map<String, dynamic> driverData = {
        'driverId': driverId,
        'driverName': driverName,
        'driverPhone': driverPhone,
        'driverAddress': driverAddress,
        'driverLicense': driverLicense,
        'experience': experience,
        'status': status,
        'assignedVehicleId': targetVehicleId,
        'assignedVehicleModel': targetVehicleId != null ? (newVehicleModel ?? '') : null,
        'assignedVehiclePlate': targetVehicleId != null ? (newVehiclePlate ?? '') : null,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!isEditing || !driverSnap.exists) {
        driverData['createdAt'] = FieldValue.serverTimestamp();
      }

      transaction.set(driverRef, driverData, SetOptions(merge: true));
    });
  }

  /// Atomically deletes a driver and releases any assigned vehicle.
  static Future<void> deleteDriver(String driverId) async {
    await FirestoreService.runTransaction((transaction) async {
      final driverRef = _driversCol.doc(driverId);
      final driverSnap = await transaction.get(driverRef);

      if (!driverSnap.exists) return;

      final assignedVehicleId =
          driverSnap.data()?['assignedVehicleId'] as String?;

      DocumentReference<Map<String, dynamic>>? vehicleRef;
      DocumentReference<Map<String, dynamic>>? assignRef;

      if (assignedVehicleId != null && assignedVehicleId.isNotEmpty) {
        vehicleRef = _vehiclesCol.doc(assignedVehicleId);
        assignRef = _assignmentsCol.doc(assignedVehicleId);
        await transaction.get(vehicleRef);
        await transaction.get(assignRef);
      }

      // Release vehicle
      if (vehicleRef != null && assignRef != null) {
        transaction.update(vehicleRef, {
          'isAssigned': false,
          'assignedDriverId': null,
          'assignedDriverName': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.delete(assignRef);
      }

      // Delete driver
      transaction.delete(driverRef);
    });
  }

  /// Atomically deletes a vehicle, deletes its assignment lock, and clears
  /// the vehicle assignment on any driver currently holding it.
  static Future<void> deleteVehicle(String vehicleId) async {
    await FirestoreService.runTransaction((transaction) async {
      final vehicleRef = _vehiclesCol.doc(vehicleId);
      final assignRef = _assignmentsCol.doc(vehicleId);

      final vehicleSnap = await transaction.get(vehicleRef);
      final assignSnap = await transaction.get(assignRef);

      if (!vehicleSnap.exists) return;

      String? driverId =
          vehicleSnap.data()?['assignedDriverId'] as String?;
      if (driverId == null || driverId.isEmpty) {
        if (assignSnap.exists) {
          driverId = assignSnap.data()?['driverId'] as String?;
        }
      }

      DocumentReference<Map<String, dynamic>>? driverRef;
      if (driverId != null && driverId.isNotEmpty) {
        driverRef = _driversCol.doc(driverId);
        await transaction.get(driverRef);
      }

      // Clear vehicle on driver
      if (driverRef != null) {
        transaction.update(driverRef, {
          'assignedVehicleId': null,
          'assignedVehicleModel': null,
          'assignedVehiclePlate': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Delete assignment lock
      if (assignSnap.exists) {
        transaction.delete(assignRef);
      }

      // Delete vehicle document
      transaction.delete(vehicleRef);
    });
  }
}
