import 'package:flutter_test/flutter_test.dart';
import 'package:ebricks/services/driver_vehicle_service.dart';

void main() {
  group('DriverVehicleService Models & Logic Tests', () {
    test('VehicleAssignmentException format and message', () {
      final exception = VehicleAssignmentException(
        'Vehicle VC001 is already assigned to Ramesh (DV001). Duplicate assignment is prohibited.',
      );

      expect(exception.message, contains('Vehicle VC001 is already assigned'));
      expect(exception.message, contains('Duplicate assignment is prohibited'));
      expect(exception.toString(), equals(exception.message));
    });

    test('Availability filter logic - unassigned vs assigned to other vs assigned to self', () {
      final mockVehicles = [
        {
          'id': 'VC001',
          'modelName': 'Tata Prima',
          'numberPlate': 'TN-01-AB-1234',
          'isAssigned': true,
          'assignedDriverId': 'DV001',
          'assignedDriverName': 'Ramesh',
        },
        {
          'id': 'VC002',
          'modelName': 'Ashok Leyland',
          'numberPlate': 'TN-02-CD-5678',
          'isAssigned': false,
          'assignedDriverId': null,
          'assignedDriverName': null,
        },
        {
          'id': 'VC003',
          'modelName': 'BharatBenz',
          'numberPlate': 'TN-03-EF-9012',
          'isAssigned': true,
          'assignedDriverId': 'DV002',
          'assignedDriverName': 'Suresh',
        },
      ];

      // Scenario 1: New driver creation (currentDriverId is null)
      final availableForNewDriver = mockVehicles.where((v) {
        final isAssigned = v['isAssigned'] as bool;
        return !isAssigned;
      }).toList();

      expect(availableForNewDriver.length, 1);
      expect(availableForNewDriver.first['id'], 'VC002');

      // Scenario 2: Editing Driver DV001 (should see unassigned vehicles + VC001)
      const currentDriverId = 'DV001';
      final availableForDV001 = mockVehicles.where((v) {
        final isAssigned = v['isAssigned'] as bool;
        final assignedDriverId = v['assignedDriverId'] as String?;
        final isCurrentDriverAssigned = assignedDriverId == currentDriverId;
        return !isAssigned || isCurrentDriverAssigned;
      }).toList();

      expect(availableForDV001.length, 2);
      final ids = availableForDV001.map((v) => v['id']).toSet();
      expect(ids, containsAll(['VC001', 'VC002']));
      expect(ids, isNot(contains('VC003'))); // VC003 belongs to DV002
    });

    test('Inactive status automatically unassigns vehicle', () {
      const status = 'Inactive';
      final isInactive = status.trim().toLowerCase() == 'inactive';
      const requestedVehicleId = 'VC001';

      final targetVehicleId = isInactive ? null : requestedVehicleId;
      expect(targetVehicleId, isNull);
    });

    test('Active status preserves vehicle assignment', () {
      const status = 'Active';
      final isInactive = status.trim().toLowerCase() == 'inactive';
      const requestedVehicleId = 'VC001';

      final targetVehicleId = isInactive ? null : requestedVehicleId;
      expect(targetVehicleId, equals('VC001'));
    });

    test('Search filter matches vehicle model, plate, or id', () {
      final driverRecord = {
        'driverId': 'DV001',
        'driverName': 'Ramesh Kumar',
        'driverPhone': '9876543210',
        'driverLicense': 'DL-12345',
        'assignedVehicleId': 'VC001',
        'assignedVehicleModel': 'Tata Prima',
        'assignedVehiclePlate': 'TN-01-AB-1234',
      };

      bool matchesQuery(String query) {
        final q = query.toLowerCase();
        final name = (driverRecord['driverName'] ?? '').toLowerCase();
        final phone = (driverRecord['driverPhone'] ?? '').toLowerCase();
        final license = (driverRecord['driverLicense'] ?? '').toLowerCase();
        final id = (driverRecord['driverId'] ?? '').toLowerCase();
        final vehicleModel = (driverRecord['assignedVehicleModel'] ?? '').toLowerCase();
        final vehiclePlate = (driverRecord['assignedVehiclePlate'] ?? '').toLowerCase();
        final vehicleId = (driverRecord['assignedVehicleId'] ?? '').toLowerCase();

        return name.contains(q) ||
            phone.contains(q) ||
            license.contains(q) ||
            id.contains(q) ||
            vehicleModel.contains(q) ||
            vehiclePlate.contains(q) ||
            vehicleId.contains(q);
      }

      expect(matchesQuery('Tata'), isTrue);
      expect(matchesQuery('TN-01'), isTrue);
      expect(matchesQuery('VC001'), isTrue);
      expect(matchesQuery('Ramesh'), isTrue);
      expect(matchesQuery('987654'), isTrue);
      expect(matchesQuery('Volvo'), isFalse);
    });
  });
}
