import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import '../services/firestore_service.dart';
import 'project_screen.dart';

class SiteScreen extends StatefulWidget {
  const SiteScreen({super.key});
  @override
  State<SiteScreen> createState() => _SiteScreenState();
}

class _SiteScreenState extends State<SiteScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _siteNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  String? _projectCategory;
  String _status = 'In-Progress';
  bool _isGettingLocation = false;
  bool _isSaving = false; // disables Save button for 3 seconds when true

  TabController? _tabController;

  // Theme colors will be derived from context

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeDefaults();
  }

  Future<void> _initializeDefaults() async {
    final statusList = await fetchProjectStatus();
    if (statusList.isNotEmpty) {
      setState(() {
        _status = statusList.first;
      });
    }
  }

  Future<List<String>> fetchProjectCategories() async {
    try {
      final snapshot = await FirestoreService.getCollection(
        'projectCategories',
      ).get();
      final categories = snapshot.docs
          .map((doc) => doc['projectCategory']?.toString().trim())
          .where((val) => val != null && val.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();
      return categories;
    } catch (e) {
      throw 'Failed to load categories: $e';
    }
  }

  Future<List<String>> fetchProjectStatus() async {
    try {
      final snapshot = await FirestoreService.getCollection(
        'projectStatus',
      ).get();
      final statusList = snapshot.docs
          .map((doc) => doc['projectState']?.toString().trim())
          .where((val) => val != null && val.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();

      // Add default status options if they are not already present
      final defaultStatuses = [
        'Planning',
        'Started',
        'In Progress',
        'On Hold',
        'Completed',
        'Cancelled',
      ];
      for (var status in defaultStatuses) {
        if (!statusList.contains(status)) {
          statusList.add(status);
        }
      }

      return statusList;
    } catch (e) {
      throw 'Failed to load status options: $e';
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: primaryColor),
            ),
          ),
          child: child!,
        );
      },
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
      final Position position;
      Position? tempPosition;
      try {
        tempPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
      } catch (e) {
        debugPrint('High accuracy getCurrentPosition failed/timed out: $e');
        // Fallback 1: Try retrieving the last known position
        tempPosition = await Geolocator.getLastKnownPosition();
        if (tempPosition == null) {
          debugPrint('Last known position is null, attempting low accuracy...');
          // Fallback 2: Try low accuracy with a short timeout as a final attempt
          tempPosition = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 5),
          );
        }
      }

      if (tempPosition == null) {
        throw 'Failed to acquire location. Please check your GPS signal and ensure location services are enabled.';
      }
      position = tempPosition;

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
        } catch (geocodingError) {
          debugPrint(
            'Geocoding error (falling back to coordinates only): $geocodingError',
          );
          address =
              'Coordinates: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
        }
      }

      setState(() {
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
        if (_locationController.text.isEmpty ||
            _locationController.text == 'Web Location') {
          _locationController.text = address;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      setState(() => _isGettingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 600;

    if (_tabController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final backgroundColor = theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Site Details',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor, primaryColor.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          tabs: const [
            Tab(text: 'New Site'),
            Tab(text: 'All Site'),
          ],
        ),
      ),
      body: SafeArea(
        bottom: true,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 600,
            ),
            child: TabBarView(
              controller: _tabController,
              children: [_buildNewSiteTab(), _buildAllSiteTab()],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNewSiteTab() {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Site Information'),
            _buildTextField(
              controller: _siteNameController,
              label: 'Site Name',
              hintText: 'Enter site name',
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Please enter site name' : null,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _locationController,
                    label: 'Location',
                    hintText: 'Enter location or get current location',
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Please enter location' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 25),
                  child: IconButton(
                    iconSize: 28,
                    tooltip: 'Get Current Location',
                    icon: _isGettingLocation
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: primaryColor,
                            ),
                          )
                        : Icon(Icons.gps_fixed, color: primaryColor),
                    onPressed: _isGettingLocation ? null : _getCurrentLocation,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
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
                const SizedBox(width: 20),
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
            const SizedBox(height: 30),
            _buildSectionTitle('Project Details'),
            FutureBuilder<List<String>>(
              future: fetchProjectCategories(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingIndicator();
                }
                if (snapshot.hasError) {
                  return _buildErrorWidget(snapshot.error.toString());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildErrorWidget('No project categories available');
                }
                final categories = snapshot.data!;
                // Ensure _projectCategory is valid for the current categories list
                String currentValue = _projectCategory ?? categories.first;
                if (!categories.contains(currentValue)) {
                  currentValue = categories.first;
                  // Use addPostFrameCallback to update state safely after build
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted)
                      setState(() => _projectCategory = categories.first);
                  });
                }

                return _buildDropdown(
                  value: currentValue,
                  items: categories,
                  label: 'Project Category',
                  onChanged: (value) =>
                      setState(() => _projectCategory = value),
                );
              },
            ),
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDateField(
                  label: 'Start Date',
                  date: _startDate,
                  onTap: () => _selectDate(context, true),
                ),
                const SizedBox(height: 20),
                _buildDateField(
                  label: 'End Date',
                  date: _endDate,
                  onTap: () => _selectDate(context, false),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FutureBuilder<List<String>>(
              future: fetchProjectStatus(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingIndicator();
                }
                if (snapshot.hasError) {
                  return _buildErrorWidget(snapshot.error.toString());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildErrorWidget('No status options available');
                }
                final statusList = snapshot.data!;
                // Ensure _status is valid for the current statusList
                String currentStatus = _status;
                if (!statusList.contains(currentStatus)) {
                  currentStatus = statusList.first;
                  // Use addPostFrameCallback to update state safely after build
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _status = statusList.first);
                  });
                }

                return _buildDropdown(
                  value: currentStatus,
                  items: statusList,
                  label: 'Project Status',
                  onChanged: (value) => setState(() => _status = value!),
                );
              },
            ),
            const SizedBox(height: 35),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  // Replace the existing _buildAllSiteTab() with this implementation
  Widget _buildAllSiteTab() {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.getCollection('Site').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No sites available.'));
        }

        final sites = snapshot.data!.docs;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 26,
            headingRowColor: MaterialStateProperty.all(
              primaryColor.withOpacity(0.1),
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
                color: MaterialStateProperty.resolveWith<Color?>(
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

  Widget _buildSectionTitle(String title) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: primaryColor,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool readOnly = false,
  }) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: primaryColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: primaryColor.withOpacity(0.7)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: primaryColor, width: 2.5),
            ),
          ),
          validator: validator,
          keyboardType: keyboardType,
          readOnly: readOnly,
          style: TextStyle(
            color: readOnly ? Colors.grey.shade700 : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required String label,
    required Function(String?) onChanged,
  }) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 7),
        DropdownButtonFormField<String>(
          value: value,
          items: items
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    item,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: primaryColor.withOpacity(0.6)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: primaryColor.withOpacity(0.4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: primaryColor, width: 2.5),
            ),
          ),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.black87,
          ),
          dropdownColor: Colors.white,
          validator: (value) => value == null ? 'Please select $label' : null,
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
    final primaryColor = theme.primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 7),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: primaryColor.withOpacity(0.6)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: primaryColor.withOpacity(0.4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: primaryColor, width: 2.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    date == null
                        ? 'Select $label'
                        : DateFormat('MMM d, yyyy').format(date),
                    style: TextStyle(
                      color: date == null
                          ? Colors.grey.shade600
                          : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.calendar_today, color: primaryColor, size: 22),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Text(
        message,
        style: TextStyle(color: Colors.red.shade700, fontSize: 15),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          context,
          icon: Icons.save,
          label: _isSaving ? 'Saving...' : 'Save',
          color: primaryColor,
          onPressed: _isSaving ? () {} : _saveSiteDetails,
        ),
        _buildActionButton(
          context,
          icon: Icons.refresh,
          label: 'Reset',
          color: Colors.orange.shade700,
          onPressed: _resetForm,
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        Material(
          shape: const CircleBorder(),
          color: color.withOpacity(0.15),
          child: IconButton(
            iconSize: 28,
            icon: Icon(icon),
            color: color,
            onPressed: onPressed,
            splashRadius: 26,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Future<void> _saveSiteDetails() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() => _isSaving = true);

    // Disable button for 3 seconds before saving
    await Future.delayed(const Duration(seconds: 3));

    final siteName = _siteNameController.text.trim();
    final location = _locationController.text.trim();
    final latitude = _latitudeController.text.trim();
    final longitude = _longitudeController.text.trim();
    final startDate = _startDate != null
        ? DateFormat('yyyy-MM-dd').format(_startDate!)
        : '';
    final endDate = _endDate != null
        ? DateFormat('yyyy-MM-dd').format(_endDate!)
        : '';
    final projectCategory = _projectCategory ?? '';
    final status = _status.isNotEmpty ? _status : 'In-Progress';

    try {
      // Deduplication: check if a Site with same siteName and location already exists
      final dupQuery = await FirestoreService.getCollection('Site')
          .where('siteName', isEqualTo: siteName)
          .where('location', isEqualTo: location)
          .limit(1)
          .get();
      if (dupQuery.docs.isNotEmpty) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Duplicate detected. Value already exists.'),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }

      final nextId = await _getNextSiteId(siteName);

      final siteData = {
        'siteId': nextId,
        'siteName': siteName,
        'location': location,
        'latitude': latitude.isNotEmpty ? double.tryParse(latitude) : null,
        'longitude': longitude.isNotEmpty ? double.tryParse(longitude) : null,
        'projectCategory': projectCategory,
        'startDate': startDate,
        'endDate': endDate,
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final siteDocId = nextId + '_' + siteName.replaceAll(' ', '');
      await FirestoreService.getCollection('Site').doc(siteDocId).set(siteData);

      // Create project with dedupe on name+siteId combination as well
      final projectsSnapshot = await FirestoreService.getCollection(
        'projects',
      ).get();
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

      final Timestamp? plannedStartDateTs = _startDate != null
          ? Timestamp.fromDate(_startDate!)
          : null;
      final Timestamp? plannedEndDateTs = _endDate != null
          ? Timestamp.fromDate(_endDate!)
          : null;

      final projectData = {
        'createdAt': FieldValue.serverTimestamp(),
        'siteId': nextId + '_' + siteName.replaceAll(' ', ''),
        'siteName': siteName,
        'plannedStartDate': plannedStartDateTs,
        'plannedEndDate': plannedEndDateTs,
        'projectCategory': projectCategory,
        'status': status,
        'siteLocation': location,
      };

      await FirestoreService.getCollection(
        'projects',
      ).doc(nextPrDocId).set(projectData);

      // Success message then navigate to ProjectScreen
      _showSuccessDialog(nextId, nextPrDocId);

      _resetForm();
    } catch (e, stack) {
      print('Error saving site/project: $e');
      print(stack);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: ${e.toString()}'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSuccessDialog(String siteId, String projectId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final theme = Theme.of(dialogContext);
        final primaryColor = theme.primaryColor;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Lottie.asset(
                      'assets/animation/success.json',
                      width: 120,
                      height: 120,
                      repeat: false,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Success!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(text: 'New site registered as '),
                      TextSpan(
                        text: siteId,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const TextSpan(
                        text:
                            '.\n\nPlease proceed to update the project configuration.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ProjectScreen(projectId: projectId),
                            ),
                          );
                        },
                        child: const Text(
                          'CONTINUE',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ],
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
      _startDate = null;
      _endDate = null;
      _projectCategory = null;
      _status = 'In-Progress';
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _siteNameController.dispose();
    _locationController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }
}
