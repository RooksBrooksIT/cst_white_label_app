import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'package:demo_cst/services/firestore_service.dart';

class SiteScreen extends StatefulWidget {
  const SiteScreen({super.key});

  @override
  State<SiteScreen> createState() => _SiteScreenState();
}

class _SiteScreenState extends State<SiteScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Site Details Controllers
  final TextEditingController _siteNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String? _projectCategory;
  String _status = 'In Progress';

  // Project Details Controllers
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

      final defaultStatuses = [
        'Planning',
        'In Progress',
        'On Hold',
        'Completed',
        'Cancelled',
      ];
      for (var s in defaultStatuses) {
        if (!statusList.contains(s)) {
          statusList.add(s);
        }
      }
      return statusList;
    } catch (_) {
      return ['Planning', 'In Progress', 'On Hold', 'Completed', 'Cancelled'];
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
  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled.';
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
      _status = 'In Progress';
      _isContractWork = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Site & Project Setup',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          tabs: const [
            Tab(text: 'New Setup'),
            Tab(text: 'All Sites'),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 650,
            ),
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildNewSiteTab(),
                _buildAllSiteTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── NEW SITE TAB ──────────────────────────────────────────────────────────
  Widget _buildNewSiteTab() {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      physics: const BouncingScrollPhysics(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SECTION 1: SITE DETAILS
            _buildSectionHeader(
              title: '1. Site Details',
              subtitle: 'Basic site information & geographical location',
              icon: Icons.location_city_rounded,
              color: primaryColor,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _siteNameController,
              label: 'Site Name *',
              hintText: 'e.g. Green Valley Site',
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
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _locationController,
                    label: 'Location / Address *',
                    hintText: 'Enter site address or fetch GPS',
                    validator: (value) =>
                        value?.trim().isEmpty ?? true ? 'Please enter location' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: IconButton.filledTonal(
                    iconSize: 22,
                    tooltip: 'Get Current Location',
                    style: IconButton.styleFrom(
                      backgroundColor: primaryColor.withValues(alpha: 0.12),
                      foregroundColor: primaryColor,
                      padding: const EdgeInsets.all(12),
                    ),
                    icon: _isGettingLocation
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: primaryColor,
                            ),
                          )
                        : const Icon(Icons.gps_fixed_rounded),
                    onPressed: _isGettingLocation ? null : _getCurrentLocation,
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
                    hintText: 'Latitude coordinates',
                    keyboardType: TextInputType.number,
                    readOnly: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _longitudeController,
                    label: 'Longitude',
                    hintText: 'Longitude coordinates',
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
                    onTap: () => _selectDate(context, true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDateField(
                    label: 'Site End Date',
                    date: _endDate,
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
                  onChanged: (val) => setState(() => _status = val ?? 'In Progress'),
                );
              },
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 20),

            // SECTION 2: PROJECT DETAILS
            _buildSectionHeader(
              title: '2. Project Details',
              subtitle: 'Financial, owner, & contract parameters for this project',
              icon: Icons.work_rounded,
              color: Colors.indigo,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _projectNameController,
              label: 'Project Name *',
              hintText: 'e.g. Green Valley Villa Construction',
              validator: (value) =>
                  value?.trim().isEmpty ?? true ? 'Please enter project name' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _ownerNameController,
                    label: 'Owner Name',
                    hintText: 'Client / Owner full name',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _ownerPhoneController,
                    label: 'Owner Phone',
                    hintText: 'Contact number',
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _projectBudgetController,
                    label: 'Project Budget (₹)',
                    hintText: 'Total budget',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _amountPaidController,
                    label: 'Advance Paid (₹)',
                    hintText: 'Initial payment',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FutureBuilder<List<String>>(
                    future: fetchProjectSubCategories(),
                    builder: (context, snapshot) {
                      final subCats = snapshot.data ?? [];
                      return _buildDropdown(
                        value: _projectSubCategory,
                        items: subCats,
                        label: 'Sub Category',
                        hint: 'Select Sub Category',
                        onChanged: (val) => setState(() => _projectSubCategory = val),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FutureBuilder<List<String>>(
                    future: fetchProjectStages(),
                    builder: (context, snapshot) {
                      final stages = snapshot.data ?? [];
                      return _buildDropdown(
                        value: _projectStage,
                        items: stages,
                        label: 'Project Stage',
                        hint: 'Select Stage',
                        onChanged: (val) => setState(() => _projectStage = val),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FutureBuilder<List<String>>(
                    future: fetchProjectContracts(),
                    builder: (context, snapshot) {
                      final contracts = snapshot.data ?? [];
                      return _buildDropdown(
                        value: _projectContract,
                        items: contracts,
                        label: 'Contract Type',
                        hint: 'Select Contract',
                        onChanged: (val) => setState(() => _projectContract = val),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FutureBuilder<List<String>>(
                    future: fetchProjectStatus(),
                    builder: (context, snapshot) {
                      final statusList = snapshot.data ?? [];
                      return _buildDropdown(
                        value: _projectStatus,
                        items: statusList,
                        label: 'Project Status',
                        hint: 'Select Status',
                        onChanged: (val) => setState(() => _projectStatus = val),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    label: 'Actual Start Date',
                    date: _actualStartDate,
                    onTap: () async {
                      final date = await _pickCustomDate(_actualStartDate);
                      if (date != null) setState(() => _actualStartDate = date);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDateField(
                    label: 'Actual End Date',
                    date: _actualEndDate,
                    onTap: () async {
                      final date = await _pickCustomDate(_actualEndDate);
                      if (date != null) setState(() => _actualEndDate = date);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            // CONTRACT WORK TOGGLE & FIELDS
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.handshake_rounded, color: Colors.teal),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Is Contract Work?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Switch(
                    value: _isContractWork,
                    activeThumbColor: primaryColor,
                    onChanged: (val) => setState(() => _isContractWork = val),
                  ),
                ],
              ),
            ),

            if (_isContractWork) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _contractorNameController,
                      label: 'Contractor Name',
                      hintText: 'e.g. ABC Contractors',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _contractorBudgetController,
                      label: 'Contractor Budget (₹)',
                      hintText: 'Budget allocated',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildDateField(
                      label: 'Contract Start Date',
                      date: _contractStartDate,
                      onTap: () async {
                        final date = await _pickCustomDate(_contractStartDate);
                        if (date != null) setState(() => _contractStartDate = date);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDateField(
                      label: 'Contract End Date',
                      date: _contractEndDate,
                      onTap: () async {
                        final date = await _pickCustomDate(_contractEndDate);
                        if (date != null) setState(() => _contractEndDate = date);
                      },
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 36),

            // SUBMIT BUTTON
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveSiteAndProject,
                icon: const Icon(Icons.check_circle_rounded, size: 22),
                label: Text(
                  _isSaving ? 'SAVING...' : 'CREATE SITE & PROJECT',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAllSiteTab() {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.getCollection('Site').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Color(0xFF0A183D)),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_off_rounded,
                  size: 64,
                  color: primaryColor.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No sites available',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A183D),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Create a new site in the "NEW SITE" tab',
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }

        final sites = snapshot.data!.docs;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 26,
            headingRowColor: WidgetStateProperty.all(
              primaryColor.withValues(alpha: 0.1),
            ),
            headingTextStyle: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: primaryColor,
            ),
            columns: const [
              DataColumn(label: Text('Site ID')),
              DataColumn(label: Text('Site Name')),
              DataColumn(label: Text('Location')),
              DataColumn(label: Text('Category')),
              DataColumn(label: Text('Status')),
            ],
            rows: List<DataRow>.generate(sites.length, (index) {
              final site = sites[index];
              final data = (site.data() as Map<String, dynamic>?) ?? const {};
              final siteId = (data['siteId'] as String?) ?? site.id;
              final siteName = (data['siteName'] as String?) ?? '';
              final location = (data['location'] as String?) ?? '';
              final projectCategory =
                  (data['projectCategory'] as String?) ?? '';
              final status = (data['status'] as String?) ?? '';

              return DataRow(
                color: WidgetStateProperty.resolveWith<Color?>(
                  (states) => index % 2 == 0 ? Colors.white : Colors.grey[50],
                ),
                cells: [
                  DataCell(Text(siteId)),
                  DataCell(Text(siteName)),
                  DataCell(Text(location)),
                  DataCell(Text(projectCategory)),
                  DataCell(Text(status)),
                ],
              );
            }),
          ),
        );
      },
    );
  }

  // -------------------- HELPER REUSABLE WIDGETS --------------------
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
          child: Icon(icon, color: color, size: 22),
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
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A183D),
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
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    void Function(String)? onChanged,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0A183D),
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
            color: Color(0xFF0A183D),
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: readOnly
                ? Colors.grey.shade100
                : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFCBD5E1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFCBD5E1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.primaryColor,
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
    required void Function(String?) onChanged,
  }) {
    final theme = Theme.of(context);
    final isValidValue = value != null && items.contains(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: isValidValue ? value : null,
          isExpanded: true,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0A183D),
          ),
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFCBD5E1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFCBD5E1),
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
  }) {
    final theme = Theme.of(context);
    final formattedDate =
        date == null ? 'Select Date' : DateFormat('dd MMM yyyy').format(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: date == null ? FontWeight.normal : FontWeight.w600,
                      color: date == null ? Colors.grey.shade400 : Colors.black87,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: theme.primaryColor,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
