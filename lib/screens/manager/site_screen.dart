import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/services/notification_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/services/subscription_limit_service.dart';

class SiteScreen extends StatefulWidget {
  final bool hideAppBar;
  final bool showBackButton;
  final VoidCallback? onBack;

  const SiteScreen({
    super.key,
    this.hideAppBar = false,
    this.showBackButton = true,
    this.onBack,
  });

  @override
  State<SiteScreen> createState() => _SiteScreenState();
}

class _SiteScreenState extends State<SiteScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Site Details Controllers (New Setup)
  final TextEditingController _siteNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String? _projectCategory;
  String? _status;

  // Project Details Controllers (New Setup)
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _ownerPhoneController = TextEditingController();
  final TextEditingController _projectBudgetController = TextEditingController();
  final TextEditingController _amountPaidController = TextEditingController();
  final TextEditingController _contractorNameController = TextEditingController();
  final TextEditingController _contractorBudgetController = TextEditingController();

  String? _projectSubCategory;
  String? _projectStage;
  String? _projectContract;
  String? _projectStatus;
  DateTime? _actualStartDate;
  DateTime? _actualEndDate;
  DateTime? _contractStartDate;
  DateTime? _contractEndDate;
  bool _isContractWork = false;

  bool _isGettingLocation = false;
  bool _isSaving = false;

  // ── UPDATE SITE STATE & CONTROLLERS ───────────────────────────────────────
  final _updateFormKey = GlobalKey<FormState>();
  String? _selectedSiteDocId;
  String? _selectedSiteId;
  String? _selectedSiteName;
  String? _selectedProjectId;
  bool _isLoadingSiteData = false;
  bool _isUpdating = false;
  bool _isGettingUpdateLocation = false;

  final TextEditingController _updateSiteNameController = TextEditingController();
  final TextEditingController _updateLocationController = TextEditingController();
  final TextEditingController _updateLatitudeController = TextEditingController();
  final TextEditingController _updateLongitudeController = TextEditingController();
  DateTime? _updateStartDate;
  DateTime? _updateEndDate;
  String? _updateProjectCategory;
  String? _updateStatus;
  DateTime? _updateActualStartDate;
  DateTime? _updateActualEndDate;

  bool _updateIsContractWork = false;
  final TextEditingController _updateContractorNameController = TextEditingController();
  final TextEditingController _updateContractorBudgetController = TextEditingController();
  DateTime? _updateContractStartDate;
  DateTime? _updateContractEndDate;

  final TextEditingController _updateProjectNameController = TextEditingController();
  final TextEditingController _updateOwnerNameController = TextEditingController();
  final TextEditingController _updateOwnerPhoneController = TextEditingController();
  final TextEditingController _updateProjectBudgetController = TextEditingController();
  final TextEditingController _updateAmountPaidController = TextEditingController();
  String? _updateProjectSubCategory;
  String? _updateProjectStage;
  String? _updateProjectContract;
  String? _updateProjectStatus;

  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _siteNameController.dispose();
    _locationController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _projectNameController.dispose();
    _ownerNameController.dispose();
    _ownerPhoneController.dispose();
    _projectBudgetController.dispose();
    _amountPaidController.dispose();
    _contractorNameController.dispose();
    _contractorBudgetController.dispose();

    _updateSiteNameController.dispose();
    _updateLocationController.dispose();
    _updateLatitudeController.dispose();
    _updateLongitudeController.dispose();
    _updateContractorNameController.dispose();
    _updateContractorBudgetController.dispose();
    _updateProjectNameController.dispose();
    _updateOwnerNameController.dispose();
    _updateOwnerPhoneController.dispose();
    _updateProjectBudgetController.dispose();
    _updateAmountPaidController.dispose();
    super.dispose();
  }

  // -------------------- DROPDOWN FETCH HELPERS --------------------
  Future<List<String>> fetchProjectCategories() async {
    try {
      final snapshot = await FirestoreService.getCollection(
        'projectCategories',
      ).get();
      return snapshot.docs
          .map((doc) => doc['projectCategory']?.toString().trim())
          .where((val) => val != null && val.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> fetchProjectSubCategories() async {
    try { 
      final snapshot = await FirestoreService.getCollection(
        'projectSubCategories',
      ).get();
      return snapshot.docs
          .map((doc) => doc['projectSubCategory']?.toString().trim())
          .where((val) => val != null && val.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> fetchProjectStages() async {
    try {
      final snapshot = await FirestoreService.getCollection(
        'projectStages',
      ).get();
      return snapshot.docs
          .map((doc) => doc['projectStage']?.toString().trim())
          .where((val) => val != null && val.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> fetchProjectContracts() async {
    try {
      final snapshot = await FirestoreService.getCollection(
        'projectContracts',
      ).get();
      return snapshot.docs
          .map((doc) => doc['projectContract']?.toString().trim())
          .where((val) => val != null && val.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> fetchProjectStatus() async {
    try {
      final snapshot = await FirestoreService.getCollection(
        'projectStatus',
      ).get();
      final statusList = snapshot.docs
          .map((doc) => (doc.data()['projectState'] ?? doc.data()['projectStatus'])?.toString().trim())
          .where((val) => val != null && val.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();

      return statusList;
    } catch (_) {
      return [];
    }
  }

  // -------------------- DATE PICKER HELPERS --------------------
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<DateTime?> _pickCustomDate(DateTime? initialDate) async {
    return await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
  }

  // ── UPDATE SITE HELPERS & LOGIC ───────────────────────────────────────────
  DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is String && val.trim().isNotEmpty) {
      return DateTime.tryParse(val.trim());
    }
    return null;
  }

  Future<void> _selectUpdateDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_updateStartDate ?? DateTime.now())
          : (_updateEndDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _updateStartDate = picked;
          if (_updateEndDate != null && _updateEndDate!.isBefore(picked)) {
            _updateEndDate = null;
          }
        } else {
          _updateEndDate = picked;
        }
      });
    }
  }

  Future<void> _loadSiteForUpdate(String docId) async {
    setState(() {
      _selectedSiteDocId = docId;
      _isLoadingSiteData = true;
    });

    try {
      final siteDoc = await FirestoreService.getCollection('Site').doc(docId).get();
      if (!siteDoc.exists) {
        setState(() => _isLoadingSiteData = false);
        return;
      }

      final siteData = siteDoc.data() ?? {};
      _selectedSiteId = (siteData['siteId'] as String?) ?? docId;
      _selectedSiteName = (siteData['siteName'] as String?) ?? '';

      _updateSiteNameController.text = _selectedSiteName ?? '';
      _updateLocationController.text = (siteData['location'] as String?) ?? '';
      _updateLatitudeController.text = siteData['latitude']?.toString() ?? '';
      _updateLongitudeController.text = siteData['longitude']?.toString() ?? '';
      _updateProjectCategory = (siteData['projectCategory'] as String?) ?? '';
      if (_updateProjectCategory != null && _updateProjectCategory!.isEmpty) {
        _updateProjectCategory = null;
      }
      _updateStatus = (siteData['status'] as String?) ?? '';
      if (_updateStatus != null && _updateStatus!.isEmpty) {
        _updateStatus = null;
      }

      _updateStartDate = _parseDate(siteData['startDate']);
      _updateEndDate = _parseDate(siteData['endDate']);
      _updateActualStartDate = _parseDate(siteData['actualStartDate'] ?? siteData['actualStateDate']);
      _updateActualEndDate = _parseDate(siteData['actualEndDate']);

      _updateIsContractWork = siteData['isContractWork'] == true;
      _updateContractorNameController.text = (siteData['contractorName'] as String?) ?? '';
      _updateContractorBudgetController.text = siteData['contractorBudget']?.toString() ?? '';
      _updateContractStartDate = _parseDate(siteData['contractStartDate']);
      _updateContractEndDate = _parseDate(siteData['contractEndDate']);

      // Also look for linked project document
      _selectedProjectId = null;
      final projectQuery = await FirestoreService.getCollection('projects')
          .where('siteId', isEqualTo: docId)
          .limit(1)
          .get();

      Map<String, dynamic> projData = {};
      if (projectQuery.docs.isNotEmpty) {
        _selectedProjectId = projectQuery.docs.first.id;
        projData = projectQuery.docs.first.data();
      } else {
        // Try matching by siteId string
        final altQuery = await FirestoreService.getCollection('projects')
            .where('siteId', isEqualTo: _selectedSiteId)
            .limit(1)
            .get();
        if (altQuery.docs.isNotEmpty) {
          _selectedProjectId = altQuery.docs.first.id;
          projData = altQuery.docs.first.data();
        }
      }

      if (projData.isNotEmpty) {
        _updateProjectNameController.text =
            (projData['projectName'] as String?) ?? _selectedSiteName ?? '';
        _updateOwnerNameController.text = (projData['ownerName'] as String?) ?? '';
        _updateOwnerPhoneController.text = (projData['ownerPhoneNumber'] as String?) ?? '';
        _updateProjectBudgetController.text = projData['projectBudget']?.toString() ?? '';
        _updateAmountPaidController.text = projData['amountPaid']?.toString() ?? '';
        _updateProjectSubCategory = (projData['projectSubCategory'] as String?) ?? '';
        if (_updateProjectSubCategory != null && _updateProjectSubCategory!.isEmpty) {
          _updateProjectSubCategory = null;
        }
        _updateProjectStage = (projData['projectStage'] as String?) ?? '';
        if (_updateProjectStage != null && _updateProjectStage!.isEmpty) {
          _updateProjectStage = null;
        }
        _updateProjectContract = (projData['projectContract'] as String?) ?? '';
        if (_updateProjectContract != null && _updateProjectContract!.isEmpty) {
          _updateProjectContract = null;
        }
        _updateProjectStatus = (projData['currentStatus'] ?? projData['status']) as String?;

        _updateActualStartDate ??=
            _parseDate(projData['actualStateDate'] ?? projData['actualStartDate']);
        _updateActualEndDate ??= _parseDate(projData['actualEndDate']);
        if (!_updateIsContractWork && projData['isContractWork'] == true) {
          _updateIsContractWork = true;
          _updateContractorNameController.text = (projData['contractorName'] as String?) ?? '';
          _updateContractorBudgetController.text =
              projData['contractorBudget']?.toString() ?? '';
          _updateContractStartDate = _parseDate(projData['contractStartDate']);
          _updateContractEndDate = _parseDate(projData['contractEndDate']);
        }
      } else {
        _updateProjectNameController.text = _selectedSiteName ?? '';
        _updateOwnerNameController.clear();
        _updateOwnerPhoneController.clear();
        _updateProjectBudgetController.clear();
        _updateAmountPaidController.clear();
        _updateProjectSubCategory = null;
        _updateProjectStage = null;
        _updateProjectContract = null;
        _updateProjectStatus = null;
      }
    } catch (e) {
      debugPrint('Error loading site for update: $e');
    } finally {
      if (mounted) setState(() => _isLoadingSiteData = false);
    }
  }

  Future<void> _getCurrentUpdateLocation() async {
    setState(() => _isGettingUpdateLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isGettingUpdateLocation = false);
        await _showEnableLocationDialog();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied';
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        throw 'Failed to acquire location signal.';
      }

      String address = '';
      if (kIsWeb) {
        address = 'Web Location';
      } else {
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          if (placemarks.isNotEmpty) {
            Placemark place = placemarks.first;
            address = [
              place.street,
              place.locality,
              place.administrativeArea,
              place.country,
            ].where((part) => part?.isNotEmpty ?? false).join(', ');
          }
        } catch (_) {
          address =
              'Coordinates: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
        }
      }

      setState(() {
        _updateLatitudeController.text = position!.latitude.toStringAsFixed(6);
        _updateLongitudeController.text = position.longitude.toStringAsFixed(6);
        if (_updateLocationController.text.isEmpty ||
            _updateLocationController.text == 'Web Location') {
          _updateLocationController.text = address;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGettingUpdateLocation = false);
    }
  }

  Future<void> _updateSiteAndProject() async {
    if (_selectedSiteDocId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a site to update.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!(_updateFormKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill out all required fields.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isUpdating = true);

    try {
      final siteName = _updateSiteNameController.text.trim();
      final location = _updateLocationController.text.trim();
      final latitude = _updateLatitudeController.text.trim();
      final longitude = _updateLongitudeController.text.trim();
      final projectName = _updateProjectNameController.text.trim().isEmpty
          ? siteName
          : _updateProjectNameController.text.trim();

      // 1. Update Site document
      final siteUpdateData = {
        'siteName': siteName,
        'location': location,
        'latitude': latitude.isNotEmpty ? double.tryParse(latitude) : null,
        'longitude': longitude.isNotEmpty ? double.tryParse(longitude) : null,
        'projectCategory': _updateProjectCategory ?? '',
        'startDate': _updateStartDate != null
            ? DateFormat('yyyy-MM-dd').format(_updateStartDate!)
            : '',
        'endDate': _updateEndDate != null
            ? DateFormat('yyyy-MM-dd').format(_updateEndDate!)
            : '',
        'status': _updateStatus,
        'actualStartDate': _updateActualStartDate != null
            ? Timestamp.fromDate(_updateActualStartDate!)
            : null,
        'actualEndDate': _updateActualEndDate != null
            ? Timestamp.fromDate(_updateActualEndDate!)
            : null,
        'isContractWork': _updateIsContractWork,
        'contractorName':
            _updateIsContractWork ? _updateContractorNameController.text.trim() : null,
        'contractorBudget': _updateIsContractWork
            ? (double.tryParse(_updateContractorBudgetController.text) ?? 0.0)
            : null,
        'contractStartDate': _updateContractStartDate != null
            ? Timestamp.fromDate(_updateContractStartDate!)
            : null,
        'contractEndDate': _updateContractEndDate != null
            ? Timestamp.fromDate(_updateContractEndDate!)
            : null,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirestoreService.getCollection('Site')
          .doc(_selectedSiteDocId)
          .update(siteUpdateData);

      // 2. Update linked project document
      final double budget =
          double.tryParse(_updateProjectBudgetController.text) ?? 0.0;
      final double amountPaid =
          double.tryParse(_updateAmountPaidController.text) ?? 0.0;

      final projectUpdateData = {
        'projectName': projectName,
        'ownerName': _updateOwnerNameController.text.trim(),
        'ownerPhoneNumber': _updateOwnerPhoneController.text.trim(),
        'projectBudget': budget,
        'amountPaid': amountPaid,
        'projectCategory': _updateProjectCategory ?? '',
        'projectSubCategory': _updateProjectSubCategory ?? '',
        'projectContract': _updateProjectContract ?? '',
        'projectStage': _updateProjectStage ?? '',
        'currentStatus': _updateProjectStatus ?? _updateStatus,
        'status': _updateProjectStatus ?? _updateStatus,
        'siteName': siteName,
        'siteLocation': location,
        'plannedStartDate': _updateStartDate != null
            ? Timestamp.fromDate(_updateStartDate!)
            : null,
        'plannedEndDate': _updateEndDate != null
            ? Timestamp.fromDate(_updateEndDate!)
            : null,
        'actualStateDate': _updateActualStartDate != null
            ? Timestamp.fromDate(_updateActualStartDate!)
            : null,
        'actualEndDate': _updateActualEndDate != null
            ? Timestamp.fromDate(_updateActualEndDate!)
            : null,
        'contractStartDate': _updateContractStartDate != null
            ? Timestamp.fromDate(_updateContractStartDate!)
            : null,
        'contractEndDate': _updateContractEndDate != null
            ? Timestamp.fromDate(_updateContractEndDate!)
            : null,
        'isContractWork': _updateIsContractWork,
        'contractorName':
            _updateIsContractWork ? _updateContractorNameController.text.trim() : null,
        'contractorBudget': _updateIsContractWork
            ? (double.tryParse(_updateContractorBudgetController.text) ?? 0.0)
            : null,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_selectedProjectId != null) {
        await FirestoreService.getCollection('projects')
            .doc(_selectedProjectId)
            .update(projectUpdateData);
      } else {
        // Query by siteId
        final query = await FirestoreService.getCollection('projects')
            .where('siteId', isEqualTo: _selectedSiteDocId)
            .get();
        for (final doc in query.docs) {
          await doc.reference.update(projectUpdateData);
        }
      }

      // Notification
      try {
        await NotificationService.notifySiteCreatedOrUpdated(
          siteId: _selectedSiteId ?? _selectedSiteDocId!,
          siteName: siteName,
          location: location,
          projectName: projectName,
          isCreated: false,
        );
      } catch (notifErr) {
        debugPrint('Notification error on update: $notifErr');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Site "${_selectedSiteId ?? siteName}" updated successfully!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update Site: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<String> _getNextSiteId(String siteName) async {
    final snapshot = await FirestoreService.getCollection('Site').get();
    int maxSiteNum = 0;
    for (final doc in snapshot.docs) {
      if (doc.data().containsKey('siteId')) {
        final siteId = doc['siteId'] as String;
        final match = RegExp(r'^ST(\d{3})').firstMatch(siteId);
        if (match != null) {
          final num = int.tryParse(match.group(1)!);
          if (num != null && num > maxSiteNum) {
            maxSiteNum = num;
          }
        }
      }
    }
    final nextNum = maxSiteNum + 1;
    return 'ST${nextNum.toString().padLeft(3, '0')}';
  }

  // -------------------- LOCATION GEOLOCATION --------------------
  Future<void> _showEnableLocationDialog() async {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_off_rounded,
                color: Color(0xFFF59E0B),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Location Turned Off',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0A183D),
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Location is turned off. Would you like to turn on Location on your phone?',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF475569),
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text(
              'No',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await Geolocator.openLocationSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor.value,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Yes',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isGettingLocation = false);
        await _showEnableLocationDialog();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied';
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        throw 'Failed to acquire location signal.';
      }

      String address = '';
      if (kIsWeb) {
        address = 'Web Location';
      } else {
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          if (placemarks.isNotEmpty) {
            Placemark place = placemarks.first;
            address = [
              place.street,
              place.locality,
              place.administrativeArea,
              place.country,
            ].where((part) => part?.isNotEmpty ?? false).join(', ');
          }
        } catch (_) {
          address =
              'Coordinates: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
        }
      }

      setState(() {
        _latitudeController.text = position!.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
        if (_locationController.text.isEmpty ||
            _locationController.text == 'Web Location') {
          _locationController.text = address;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  // -------------------- ATOMIC SAVE LOGIC --------------------
  Future<void> _saveSiteAndProject() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill out all required fields.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final siteName = _siteNameController.text.trim();
    final location = _locationController.text.trim();
    final latitude = _latitudeController.text.trim();
    final longitude = _longitudeController.text.trim();
    final projectName = _projectNameController.text.trim().isEmpty
        ? siteName
        : _projectNameController.text.trim();

    setState(() => _isSaving = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Creating Site & Project...',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );

    String? createdSiteDocId;

    try {
      // Validate active subscription site limit
      final subValidation = await SubscriptionLimitService.canCreateSite();
      if (!subValidation.isAllowed) {
        if (mounted) Navigator.pop(context); // Close progress dialog
        if (mounted) {
          await SubscriptionLimitService.showLimitReachedDialog(
            context,
            title: 'Site Limit Reached',
            message: subValidation.errorMessage ??
                'You have reached your subscription plan limit for active sites.',
          );
        }
        return;
      }

      // 1. Check for Duplicate Site
      final dupQuery = await FirestoreService.getCollection('Site')
          .where('siteName', isEqualTo: siteName)
          .where('location', isEqualTo: location)
          .limit(1)
          .get();

      if (dupQuery.docs.isNotEmpty) {
        if (mounted) Navigator.pop(context); // Close progress dialog
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  const Text('Site with this name and location already exists.'),
              backgroundColor: Colors.orange.shade700,
            ),
          );
        }
        return;
      }

      // 2. Generate Site ID
      final nextSiteId = await _getNextSiteId(siteName);
      createdSiteDocId = '${nextSiteId}_${siteName.replaceAll(' ', '')}';

      final siteData = {
        'siteId': nextSiteId,
        'siteName': siteName,
        'location': location,
        'latitude': latitude.isNotEmpty ? double.tryParse(latitude) : null,
        'longitude': longitude.isNotEmpty ? double.tryParse(longitude) : null,
        'projectCategory': _projectCategory ?? '',
        'startDate': _startDate != null
            ? DateFormat('yyyy-MM-dd').format(_startDate!)
            : '',
        'endDate': _endDate != null
            ? DateFormat('yyyy-MM-dd').format(_endDate!)
            : '',
        'status': _status,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 3. Save Site
      await FirestoreService.getCollection('Site')
          .doc(createdSiteDocId)
          .set(siteData);

      // Trigger real-time notification to Organization
      try {
        await NotificationService.notifySiteCreatedOrUpdated(
          siteId: nextSiteId,
          siteName: siteName,
          location: location,
          projectName: projectName,
          isCreated: true,
        );
      } catch (notifErr) {
        debugPrint('Error triggering site creation notification: $notifErr');
      }

      // 4. Save Project (with Rollback safety if Project fails)
      try {
        final projectsSnapshot =
            await FirestoreService.getCollection('projects').get();
        int maxPRNum = 0;
        for (final doc in projectsSnapshot.docs) {
          final docId = doc.id;
          if (docId.startsWith('PR')) {
            final numeric = int.tryParse(docId.substring(2));
            if (numeric != null && numeric > maxPRNum) {
              maxPRNum = numeric;
            }
          }
        }
        final nextPrDocId = 'PR${(maxPRNum + 1).toString().padLeft(3, '0')}';

        final double budget =
            double.tryParse(_projectBudgetController.text) ?? 0.0;
        final double amountPaid =
            double.tryParse(_amountPaidController.text) ?? 0.0;

        final projectData = {
          'projectId': nextPrDocId,
          'projectName': projectName,
          'ownerName': _ownerNameController.text.trim(),
          'ownerPhoneNumber': _ownerPhoneController.text.trim(),
          'amountPaid': amountPaid,
          'amountSpent': 0.0,
          'amountBalance': amountPaid,
          'projectBudget': budget,
          'projectCategory': _projectCategory ?? '',
          'projectSubCategory': _projectSubCategory ?? '',
          'projectContract': _projectContract ?? '',
          'projectStage': _projectStage ?? '',
          'currentStatus': _projectStatus ?? _status,
          'status': _projectStatus ?? _status,
          'siteId': createdSiteDocId,
          'siteName': siteName,
          'siteLocation': location,
          'plannedStartDate': _startDate != null
              ? Timestamp.fromDate(_startDate!)
              : Timestamp.now(),
          'plannedEndDate':
              _endDate != null ? Timestamp.fromDate(_endDate!) : null,
          'actualStateDate': _actualStartDate != null
              ? Timestamp.fromDate(_actualStartDate!)
              : null,
          'actualEndDate': _actualEndDate != null
              ? Timestamp.fromDate(_actualEndDate!)
              : null,
          'contractStartDate': _contractStartDate != null
              ? Timestamp.fromDate(_contractStartDate!)
              : null,
          'contractEndDate': _contractEndDate != null
              ? Timestamp.fromDate(_contractEndDate!)
              : null,
          'isContractWork': _isContractWork,
          'contractorName':
              _isContractWork ? _contractorNameController.text.trim() : null,
          'contractorBudget': _isContractWork
              ? (double.tryParse(_contractorBudgetController.text) ?? 0.0)
              : null,
          'createdAt': FieldValue.serverTimestamp(),
        };

        await FirestoreService.getCollection('projects')
            .doc(nextPrDocId)
            .set(projectData);

        // Initialize Expenses Tracker
        await FirestoreService.getCollection('totalSiteExpensesPerDay')
            .doc(createdSiteDocId)
            .set({
          'siteId': createdSiteDocId,
          'totalMgrExpense': 0.0,
          'totalOrgExpense': 0.0,
          'totalSiteExpense': 0.0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (projectError) {
        // Rollback Site document if Project creation fails
        try {
          await FirestoreService.getCollection('Site')
              .doc(createdSiteDocId)
              .delete();
        } catch (_) {}
        rethrow;
      }

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (mounted) {
        _showSuccessDialog(nextSiteId, projectName);
        _resetForm();
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context); // ensure loading dialog is dismissed
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save Site & Project: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSuccessDialog(String siteId, String projectName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final theme = Theme.of(dialogContext);
        final primaryColor = theme.primaryColor;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animation/success.json',
                  width: 100,
                  height: 100,
                  repeat: false,
                ),
                const SizedBox(height: 16),
                Text(
                  'Site & Project Created!',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Site ID "$siteId" and Project "$projectName" have been successfully registered.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _tabController?.animateTo(1); // switch to All Site tab
                    },
                    child: const Text(
                      'VIEW ALL SITES',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _resetForm() {
    setState(() {
      _siteNameController.clear();
      _locationController.clear();
      _latitudeController.clear();
      _longitudeController.clear();
      _projectNameController.clear();
      _ownerNameController.clear();
      _ownerPhoneController.clear();
      _projectBudgetController.clear();
      _amountPaidController.clear();
      _contractorNameController.clear();
      _contractorBudgetController.clear();
      _startDate = null;
      _endDate = null;
      _actualStartDate = null;
      _actualEndDate = null;
      _contractStartDate = null;
      _contractEndDate = null;
      _projectCategory = null;
      _projectSubCategory = null;
      _projectStage = null;
      _projectContract = null;
      _projectStatus = null;
      _status = null;
      _isContractWork = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, primaryColor, _) {
        final darkAccent = AppTheme.getDarkAccent(primaryColor);
        final dynamicGradientColors = AppTheme.getBackgroundGradientColors(
          primaryColor,
        );

        return PopScope(
          canPop: widget.onBack == null && Navigator.canPop(context),
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (widget.onBack != null) {
              widget.onBack!();
            } else if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dynamicGradientColors,
                stops: const [0.0, 0.35, 0.7, 1.0],
              ),
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                bottom: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isMobile ? double.infinity : 650,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!widget.hideAppBar) ...[
                          // Top Header
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Row(
                              children: [
                                if ((widget.showBackButton &&
                                        Navigator.canPop(context)) ||
                                    widget.onBack != null)
                                  InkWell(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      if (widget.onBack != null) {
                                        widget.onBack!();
                                      } else if (Navigator.canPop(context)) {
                                        Navigator.pop(context);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: 38,
                                      height: 38,
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1.2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF0F172A)
                                                .withValues(alpha: 0.05),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.arrow_back_ios_new_rounded,
                                        size: 16,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'Project & Site Setup',
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF0F172A),
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: primaryColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'Setup',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w800,
                                                color: primaryColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Configure parameters, location & budget',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Segmented Pill Switcher Tabs
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: AnimatedBuilder(
                                animation: _tabController!,
                                builder: (context, _) {
                                  final currentIndex = _tabController!.index;
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () {
                                            HapticFeedback.lightImpact();
                                            _tabController!.animateTo(0);
                                            setState(() {});
                                          },
                                          borderRadius: BorderRadius.circular(12),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            padding: const EdgeInsets.symmetric(vertical: 9),
                                            decoration: BoxDecoration(
                                              gradient: currentIndex == 0
                                                  ? LinearGradient(
                                                      colors: [primaryColor, darkAccent],
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                    )
                                                  : null,
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: currentIndex == 0
                                                  ? [
                                                      BoxShadow(
                                                        color: primaryColor.withValues(alpha: 0.35),
                                                        blurRadius: 8,
                                                        offset: const Offset(0, 3),
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            child: Center(
                                              child: Text(
                                                'New Setup',
                                                style: TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: currentIndex == 0
                                                      ? FontWeight.w800
                                                      : FontWeight.w600,
                                                  color: currentIndex == 0
                                                      ? Colors.white
                                                      : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: InkWell(
                                          onTap: () {
                                            HapticFeedback.lightImpact();
                                            _tabController!.animateTo(1);
                                            setState(() {});
                                          },
                                          borderRadius: BorderRadius.circular(12),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            padding: const EdgeInsets.symmetric(vertical: 9),
                                            decoration: BoxDecoration(
                                              gradient: currentIndex == 1
                                                  ? LinearGradient(
                                                      colors: [primaryColor, darkAccent],
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                    )
                                                  : null,
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: currentIndex == 1
                                                  ? [
                                                      BoxShadow(
                                                        color: primaryColor.withValues(alpha: 0.35),
                                                        blurRadius: 8,
                                                        offset: const Offset(0, 3),
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            child: Center(
                                              child: Text(
                                                'Update Site',
                                                style: TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: currentIndex == 1
                                                      ? FontWeight.w800
                                                      : FontWeight.w600,
                                                  color: currentIndex == 1
                                                      ? Colors.white
                                                      : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ],

                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildNewSiteTab(primaryColor, darkAccent),
                              _buildUpdateSiteTab(primaryColor, darkAccent),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── NEW SITE TAB ──────────────────────────────────────────────────────────
  Widget _buildNewSiteTab(Color primaryColor, Color darkAccent) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      physics: const BouncingScrollPhysics(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── BENTO CARD 1: SITE DETAILS ──────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                    title: '1. Site Details',
                    subtitle: 'Basic site information & geographical coordinates',
                    icon: Icons.location_city_rounded,
                    color: primaryColor,
                  ),
                  const SizedBox(height: 18),
                  _buildTextField(
                    controller: _siteNameController,
                    label: 'Site Name *',
                    hintText: 'e.g. Green Valley Site',
                    primaryColor: primaryColor,
                    validator: (value) =>
                        value?.trim().isEmpty ?? true ? 'Please enter site name' : null,
                    onChanged: (val) {
                      if (_projectNameController.text.isEmpty ||
                          _siteNameController.text.startsWith(_projectNameController.text)) {
                        _projectNameController.text = val;
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _locationController,
                          label: 'Location / Address *',
                          hintText: 'Enter site address or fetch GPS',
                          primaryColor: primaryColor,
                          validator: (value) =>
                              value?.trim().isEmpty ?? true ? 'Please enter location' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: InkWell(
                          onTap: _isGettingLocation ? null : _getCurrentLocation,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  primaryColor.withValues(alpha: 0.15),
                                  primaryColor.withValues(alpha: 0.06),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: primaryColor.withValues(alpha: 0.25),
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: _isGettingLocation
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: primaryColor,
                                      ),
                                    )
                                  : Icon(
                                      Icons.gps_fixed_rounded,
                                      color: primaryColor,
                                      size: 22,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _latitudeController,
                          label: 'Latitude',
                          hintText: 'Coordinates',
                          primaryColor: primaryColor,
                          keyboardType: TextInputType.number,
                          readOnly: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _longitudeController,
                          label: 'Longitude',
                          hintText: 'Coordinates',
                          primaryColor: primaryColor,
                          keyboardType: TextInputType.number,
                          readOnly: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<List<String>>(
                    future: fetchProjectCategories(),
                    builder: (context, snapshot) {
                      final categories = snapshot.data ?? [];
                      return _buildDropdown(
                        value: _projectCategory,
                        items: categories,
                        label: 'Project Category',
                        hint: 'Select Category',
                        primaryColor: primaryColor,
                        onChanged: (val) => setState(() => _projectCategory = val),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateField(
                          label: 'Site Start Date',
                          date: _startDate,
                          primaryColor: primaryColor,
                          onTap: () => _selectDate(context, true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDateField(
                          label: 'Site End Date',
                          date: _endDate,
                          primaryColor: primaryColor,
                          onTap: () => _selectDate(context, false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<List<String>>(
                    future: fetchProjectStatus(),
                    builder: (context, snapshot) {
                      final statusList = snapshot.data ?? [];
                      return _buildDropdown(
                        value: _status,
                        items: statusList,
                        label: 'Site Status',
                        hint: 'Select Status',
                        primaryColor: primaryColor,
                        onChanged: (val) => setState(() => _status = val),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateField(
                          label: 'Actual Start Date',
                          date: _actualStartDate,
                          primaryColor: primaryColor,
                          onTap: () async {
                            final date = await _pickCustomDate(_actualStartDate);
                            if (date != null) setState(() => _actualStartDate = date);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDateField(
                          label: 'Actual End Date',
                          date: _actualEndDate,
                          primaryColor: primaryColor,
                          onTap: () async {
                            final date = await _pickCustomDate(_actualEndDate);
                            if (date != null) setState(() => _actualEndDate = date);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── BENTO CARD 2: CONTRACT WORK ─────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.handshake_rounded,
                          color: primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '2. Contract Work',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'Third-party contractor allocation',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isContractWork,
                        activeThumbColor: primaryColor,
                        onChanged: (val) => setState(() => _isContractWork = val),
                      ),
                    ],
                  ),
                  if (_isContractWork) ...[
                    const SizedBox(height: 18),
                    _buildTextField(
                      controller: _contractorNameController,
                      label: 'Contractor Name',
                      hintText: 'e.g. Apex Builders Ltd',
                      primaryColor: primaryColor,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _contractorBudgetController,
                      label: 'Contractor Budget (₹)',
                      hintText: 'e.g. 500000',
                      primaryColor: primaryColor,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateField(
                            label: 'Contract Start',
                            date: _contractStartDate,
                            primaryColor: primaryColor,
                            onTap: () async {
                              final date = await _pickCustomDate(_contractStartDate);
                              if (date != null) setState(() => _contractStartDate = date);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDateField(
                            label: 'Contract End',
                            date: _contractEndDate,
                            primaryColor: primaryColor,
                            onTap: () async {
                              final date = await _pickCustomDate(_contractEndDate);
                              if (date != null) setState(() => _contractEndDate = date);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── BENTO CARD 3: PROJECT CONFIGURATION ───────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                    title: '3. Project Configuration',
                    subtitle: 'Linked project metadata, stage & budget',
                    icon: Icons.architecture_rounded,
                    color: primaryColor,
                  ),
                  const SizedBox(height: 18),
                  _buildTextField(
                    controller: _projectNameController,
                    label: 'Project Name *',
                    hintText: 'e.g. Tower A Construction',
                    primaryColor: primaryColor,
                    validator: (val) =>
                        val?.trim().isEmpty ?? true ? 'Please enter project name' : null,
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<List<String>>(
                    future: fetchProjectSubCategories(),
                    builder: (context, snapshot) {
                      final subCategories = snapshot.data ?? [];
                      return _buildDropdown(
                        value: _projectSubCategory,
                        items: subCategories,
                        label: 'Project Sub-Category',
                        hint: 'Select Sub-Category',
                        primaryColor: primaryColor,
                        onChanged: (val) => setState(() => _projectSubCategory = val),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<List<String>>(
                    future: fetchProjectStages(),
                    builder: (context, snapshot) {
                      final stages = snapshot.data ?? [];
                      return _buildDropdown(
                        value: _projectStage,
                        items: stages,
                        label: 'Project Stage',
                        hint: 'Select Stage',
                        primaryColor: primaryColor,
                        onChanged: (val) => setState(() => _projectStage = val),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<List<String>>(
                    future: fetchProjectContracts(),
                    builder: (context, snapshot) {
                      final contracts = snapshot.data ?? [];
                      return _buildDropdown(
                        value: _projectContract,
                        items: contracts,
                        label: 'Project Contract Type',
                        hint: 'Select Contract Type',
                        primaryColor: primaryColor,
                        onChanged: (val) => setState(() => _projectContract = val),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _projectBudgetController,
                          label: 'Estimated Budget (₹)',
                          hintText: 'e.g. 2500000',
                          primaryColor: primaryColor,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _amountPaidController,
                          label: 'Advance / Paid (₹)',
                          hintText: 'e.g. 500000',
                          primaryColor: primaryColor,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _ownerNameController,
                          label: 'Client / Owner Name',
                          hintText: 'e.g. John Doe',
                          primaryColor: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _ownerPhoneController,
                          label: 'Client Phone',
                          hintText: 'e.g. 9876543210',
                          primaryColor: primaryColor,
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── SUBMIT BUTTON ───────────────────────────────────────────────
            Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [primaryColor, darkAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isSaving ? null : _saveSiteAndProject,
                  borderRadius: BorderRadius.circular(16),
                  child: Center(
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'CREATE SITE & PROJECT',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── UPDATE SITE TAB ───────────────────────────────────────────────────────
  Widget _buildUpdateSiteTab(Color primaryColor, Color darkAccent) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── SITE SELECTION BENTO CARD ────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  title: 'Select Site',
                  subtitle: 'Choose an existing site to view and modify parameters',
                  icon: Icons.edit_location_alt_rounded,
                  color: primaryColor,
                ),
                const SizedBox(height: 18),
                StreamBuilder<QuerySnapshot>(
                  stream: FirestoreService.getCollection('Site').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                          ),
                        ),
                      );
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: Colors.orange, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No sites found to update. Create a new site first.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return DropdownButtonFormField<String>(
                      key: ValueKey(_selectedSiteDocId),
                      initialValue: _selectedSiteDocId != null &&
                              docs.any((d) => d.id == _selectedSiteDocId)
                          ? _selectedSiteDocId
                          : null,
                      isExpanded: true,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        labelText: 'Choose Construction Site *',
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                        ),
                        hintText: 'Select a site to edit...',
                        hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey.shade400),
                        prefixIcon: Icon(Icons.location_city_rounded, color: primaryColor, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: primaryColor,
                            width: 1.8,
                          ),
                        ),
                      ),
                      items: docs.map((doc) {
                        final data = (doc.data() as Map<String, dynamic>?) ?? {};
                        final sId = (data['siteId'] as String?) ?? doc.id;
                        final sName = (data['siteName'] as String?) ?? 'Unnamed Site';
                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text(
                            '$sId — $sName',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (docId) {
                        if (docId != null) {
                          _loadSiteForUpdate(docId);
                        }
                      },
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── LOADING INDICATOR ─────────────────────────────────────────────
          if (_isLoadingSiteData)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Loading site parameters...',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            )
          // ── NO SITE SELECTED EMPTY STATE ──────────────────────────────────
          else if (_selectedSiteDocId == null)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.touch_app_rounded,
                      size: 40,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Site Selected',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Please select a construction site from the dropdown above to load and update its values.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            )
          // ── EDITABLE FORM ─────────────────────────────────────────────────
          else
            Form(
              key: _updateFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── ACTIVE SITE INDICATOR BANNER ──────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primaryColor.withValues(alpha: 0.12),
                          primaryColor.withValues(alpha: 0.04),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            _selectedSiteId ?? 'SITE',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedSiteName ?? 'Selected Site',
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Currently modifying values for this site only',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Color(0xFF10B981),
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── BENTO CARD 1: SITE DETAILS ────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          title: '1. Site Details',
                          subtitle: 'Basic site information & geographical coordinates',
                          icon: Icons.location_city_rounded,
                          color: primaryColor,
                        ),
                        const SizedBox(height: 18),
                        _buildTextField(
                          controller: _updateSiteNameController,
                          label: 'Site Name *',
                          hintText: 'e.g. Green Valley Site',
                          primaryColor: primaryColor,
                          validator: (value) =>
                              value?.trim().isEmpty ?? true ? 'Please enter site name' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _updateLocationController,
                                label: 'Location / Address *',
                                hintText: 'Enter site address or fetch GPS',
                                primaryColor: primaryColor,
                                validator: (value) =>
                                    value?.trim().isEmpty ?? true ? 'Please enter location' : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 1),
                              child: InkWell(
                                onTap: _isGettingUpdateLocation ? null : _getCurrentUpdateLocation,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        primaryColor.withValues(alpha: 0.15),
                                        primaryColor.withValues(alpha: 0.06),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: primaryColor.withValues(alpha: 0.25),
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: _isGettingUpdateLocation
                                        ? SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: primaryColor,
                                            ),
                                          )
                                        : Icon(
                                            Icons.gps_fixed_rounded,
                                            color: primaryColor,
                                            size: 22,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _updateLatitudeController,
                                label: 'Latitude',
                                hintText: 'Coordinates',
                                primaryColor: primaryColor,
                                keyboardType: TextInputType.number,
                                readOnly: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: _updateLongitudeController,
                                label: 'Longitude',
                                hintText: 'Coordinates',
                                primaryColor: primaryColor,
                                keyboardType: TextInputType.number,
                                readOnly: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FutureBuilder<List<String>>(
                          future: fetchProjectCategories(),
                          builder: (context, snapshot) {
                            final categories = snapshot.data ?? [];
                            return _buildDropdown(
                              value: _updateProjectCategory,
                              items: categories,
                              label: 'Project Category',
                              hint: 'Select Category',
                              primaryColor: primaryColor,
                              onChanged: (val) => setState(() => _updateProjectCategory = val),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDateField(
                                label: 'Site Start Date',
                                date: _updateStartDate,
                                primaryColor: primaryColor,
                                onTap: () => _selectUpdateDate(context, true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDateField(
                                label: 'Site End Date',
                                date: _updateEndDate,
                                primaryColor: primaryColor,
                                onTap: () => _selectUpdateDate(context, false),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FutureBuilder<List<String>>(
                          future: fetchProjectStatus(),
                          builder: (context, snapshot) {
                            final statusList = snapshot.data ?? [];
                            return _buildDropdown(
                              value: _updateStatus,
                              items: statusList,
                              label: 'Site Status',
                              hint: 'Select Status',
                              primaryColor: primaryColor,
                              onChanged: (val) => setState(() => _updateStatus = val),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDateField(
                                label: 'Actual Start Date',
                                date: _updateActualStartDate,
                                primaryColor: primaryColor,
                                onTap: () async {
                                  final date = await _pickCustomDate(_updateActualStartDate);
                                  if (date != null) setState(() => _updateActualStartDate = date);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDateField(
                                label: 'Actual End Date',
                                date: _updateActualEndDate,
                                primaryColor: primaryColor,
                                onTap: () async {
                                  final date = await _pickCustomDate(_updateActualEndDate);
                                  if (date != null) setState(() => _updateActualEndDate = date);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── BENTO CARD 2: CONTRACT WORK ───────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.handshake_rounded,
                                color: primaryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '2. Contract Work',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  Text(
                                    'Third-party contractor allocation',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _updateIsContractWork,
                              activeThumbColor: primaryColor,
                              onChanged: (val) => setState(() => _updateIsContractWork = val),
                            ),
                          ],
                        ),
                        if (_updateIsContractWork) ...[
                          const SizedBox(height: 18),
                          _buildTextField(
                            controller: _updateContractorNameController,
                            label: 'Contractor Name',
                            hintText: 'e.g. Apex Builders Ltd',
                            primaryColor: primaryColor,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _updateContractorBudgetController,
                            label: 'Contractor Budget (₹)',
                            hintText: 'e.g. 500000',
                            primaryColor: primaryColor,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDateField(
                                  label: 'Contract Start',
                                  date: _updateContractStartDate,
                                  primaryColor: primaryColor,
                                  onTap: () async {
                                    final date = await _pickCustomDate(_updateContractStartDate);
                                    if (date != null) setState(() => _updateContractStartDate = date);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildDateField(
                                  label: 'Contract End',
                                  date: _updateContractEndDate,
                                  primaryColor: primaryColor,
                                  onTap: () async {
                                    final date = await _pickCustomDate(_updateContractEndDate);
                                    if (date != null) setState(() => _updateContractEndDate = date);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── BENTO CARD 3: PROJECT CONFIGURATION ─────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          title: '3. Project Configuration',
                          subtitle: 'Linked project metadata, stage & budget',
                          icon: Icons.architecture_rounded,
                          color: primaryColor,
                        ),
                        const SizedBox(height: 18),
                        _buildTextField(
                          controller: _updateProjectNameController,
                          label: 'Project Name *',
                          hintText: 'e.g. Tower A Construction',
                          primaryColor: primaryColor,
                          validator: (val) =>
                              val?.trim().isEmpty ?? true ? 'Please enter project name' : null,
                        ),
                        const SizedBox(height: 16),
                        FutureBuilder<List<String>>(
                          future: fetchProjectSubCategories(),
                          builder: (context, snapshot) {
                            final subCategories = snapshot.data ?? [];
                            return _buildDropdown(
                              value: _updateProjectSubCategory,
                              items: subCategories,
                              label: 'Project Sub-Category',
                              hint: 'Select Sub-Category',
                              primaryColor: primaryColor,
                              onChanged: (val) => setState(() => _updateProjectSubCategory = val),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        FutureBuilder<List<String>>(
                          future: fetchProjectStages(),
                          builder: (context, snapshot) {
                            final stages = snapshot.data ?? [];
                            return _buildDropdown(
                              value: _updateProjectStage,
                              items: stages,
                              label: 'Project Stage',
                              hint: 'Select Stage',
                              primaryColor: primaryColor,
                              onChanged: (val) => setState(() => _updateProjectStage = val),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        FutureBuilder<List<String>>(
                          future: fetchProjectContracts(),
                          builder: (context, snapshot) {
                            final contracts = snapshot.data ?? [];
                            return _buildDropdown(
                              value: _updateProjectContract,
                              items: contracts,
                              label: 'Project Contract Type',
                              hint: 'Select Contract Type',
                              primaryColor: primaryColor,
                              onChanged: (val) => setState(() => _updateProjectContract = val),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _updateProjectBudgetController,
                                label: 'Estimated Budget (₹)',
                                hintText: 'e.g. 2500000',
                                primaryColor: primaryColor,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: _updateAmountPaidController,
                                label: 'Advance / Paid (₹)',
                                hintText: 'e.g. 500000',
                                primaryColor: primaryColor,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _updateOwnerNameController,
                                label: 'Client / Owner Name',
                                hintText: 'e.g. John Doe',
                                primaryColor: primaryColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: _updateOwnerPhoneController,
                                label: 'Client Phone',
                                hintText: 'e.g. 9876543210',
                                primaryColor: primaryColor,
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── UPDATE BUTTON ─────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [primaryColor, darkAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isUpdating ? null : _updateSiteAndProject,
                        borderRadius: BorderRadius.circular(16),
                        child: Center(
                          child: _isUpdating
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.save_rounded, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'UPDATE SITE',
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── HELPER REUSABLE WIDGETS ───────────────────────────────────────────────
  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    Color? primaryColor,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    void Function(String)? onChanged,
  }) {
    final effectivePrimary = primaryColor ?? AppTheme.primaryColor.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          readOnly: readOnly,
          onChanged: onChanged,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey.shade400),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: readOnly ? const Color(0xFFF8FAFC) : const Color(0xFFF8FAFC),
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
              borderSide: BorderSide(
                color: effectivePrimary,
                width: 1.8,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String label,
    required String hint,
    Color? primaryColor,
    required void Function(String?) onChanged,
  }) {
    final isValidValue = value != null && items.contains(value);
    final effectivePrimary = primaryColor ?? AppTheme.primaryColor.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: isValidValue ? value : null,
          isExpanded: true,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
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
              borderSide: BorderSide(
                color: effectivePrimary,
                width: 1.8,
              ),
            ),
          ),
          hint: Text(
            hint,
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade400),
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    Color? primaryColor,
  }) {
    final effectivePrimary = primaryColor ?? AppTheme.primaryColor.value;
    final formattedDate =
        date == null ? 'Select Date' : DateFormat('dd MMM yyyy').format(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: date == null ? FontWeight.normal : FontWeight.w600,
                      color: date == null ? Colors.grey.shade400 : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: effectivePrimary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

