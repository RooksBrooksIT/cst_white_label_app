import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/screens/manager/project_screen.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';

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
  bool _isSaving = false;

  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController!.addListener(() => setState(() {}));
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
        tempPosition = await Geolocator.getLastKnownPosition();
        if (tempPosition == null) {
          tempPosition = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 5),
          );
        }
      }

      if (tempPosition == null) {
        throw 'Failed to acquire location. Please check GPS signal.';
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
    final Color darkCardBg = AppTheme.getDarkAccent(primaryColor);

    return GlassScaffold(
      padding: EdgeInsets.zero,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header Row ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.getDarkAccent(AppTheme.primaryColor.value),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.getDarkAccent(AppTheme.primaryColor.value).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Text(
                    'Site Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.getDarkAccent(AppTheme.primaryColor.value),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // ── Dark Pill Tab Switcher ──────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: darkCardBg,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: darkCardBg.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: AnimatedBuilder(
                animation: _tabController!,
                builder: (context, _) {
                  return Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _tabController!.animateTo(0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _tabController!.index == 0
                                  ? primaryColor
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_location_alt_rounded,
                                  size: 16,
                                  color: _tabController!.index == 0
                                      ? Colors.white
                                      : const Color(0xFFCBD5E1),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'NEW SITE',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: _tabController!.index == 0
                                        ? Colors.white
                                        : const Color(0xFFCBD5E1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _tabController!.animateTo(1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _tabController!.index == 1
                                  ? primaryColor
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.location_city_rounded,
                                  size: 16,
                                  color: _tabController!.index == 1
                                      ? Colors.white
                                      : const Color(0xFFCBD5E1),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'ALL SITES',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: _tabController!.index == 1
                                        ? Colors.white
                                        : const Color(0xFFCBD5E1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // ── Tab Bar View Body ───────────────────────────────────────────
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isMobile ? double.infinity : 600,
                  ),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildNewSiteTab(darkCardBg, primaryColor),
                      _buildAllSiteTab(darkCardBg, primaryColor),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── NEW SITE TAB ──────────────────────────────────────────────────────────
  Widget _buildNewSiteTab(Color darkCardBg, Color primaryColor) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Site Information Card ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: darkCardBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: darkCardBg.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Site Information'),
                  const SizedBox(height: 18),
                  _buildTextField(
                    controller: _siteNameController,
                    label: 'Site Name',
                    hintText: 'Enter site name',
                    icon: Icons.business_rounded,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Please enter site name' : null,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _locationController,
                          label: 'Location',
                          hintText: 'Enter location or get GPS',
                          icon: Icons.location_on_rounded,
                          validator: (value) =>
                              value?.isEmpty ?? true
                                  ? 'Please enter location'
                                  : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 48,
                        height: 48,
                        margin: const EdgeInsets.only(bottom: 2),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: IconButton(
                          tooltip: 'Get Current Location',
                          icon: _isGettingLocation
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Color(0xFF0A183D),
                                  ),
                                )
                              : const Icon(
                                  Icons.my_location_rounded,
                                  color: Color(0xFF0A183D),
                                  size: 22,
                                ),
                          onPressed: _isGettingLocation
                              ? null
                              : _getCurrentLocation,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _latitudeController,
                          label: 'Latitude',
                          hintText: 'Latitude coordinates',
                          keyboardType: TextInputType.number,
                          readOnly: true,
                          icon: Icons.explore_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _longitudeController,
                          label: 'Longitude',
                          hintText: 'Longitude coordinates',
                          keyboardType: TextInputType.number,
                          readOnly: true,
                          icon: Icons.explore_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Project Details Card ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: darkCardBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: darkCardBg.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Project Details'),
                  const SizedBox(height: 18),
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
                      String currentValue = _projectCategory ?? categories.first;
                      if (!categories.contains(currentValue)) {
                        currentValue = categories.first;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted)
                            setState(() => _projectCategory = categories.first);
                        });
                      }

                      return _buildDropdown(
                        value: currentValue,
                        items: categories,
                        label: 'Project Category',
                        icon: Icons.category_rounded,
                        onChanged: (value) =>
                            setState(() => _projectCategory = value),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildDateField(
                    label: 'Start Date',
                    date: _startDate,
                    onTap: () => _selectDate(context, true),
                  ),
                  const SizedBox(height: 14),
                  _buildDateField(
                    label: 'End Date',
                    date: _endDate,
                    onTap: () => _selectDate(context, false),
                  ),
                  const SizedBox(height: 14),
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
                      String currentStatus = _status;
                      if (!statusList.contains(currentStatus)) {
                        currentStatus = statusList.first;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _status = statusList.first);
                        });
                      }

                      return _buildDropdown(
                        value: currentStatus,
                        items: statusList,
                        label: 'Project Status',
                        icon: Icons.timeline_rounded,
                        onChanged: (value) => setState(() => _status = value!),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Action Buttons ────────────────────────────────────────────
            _buildActionButtons(context, primaryColor),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── ALL SITES TAB ─────────────────────────────────────────────────────────
  Widget _buildAllSiteTab(Color darkCardBg, Color primaryColor) {
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

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: sites.length,
          itemBuilder: (context, index) {
            final site = sites[index];
            final data = (site.data() as Map<String, dynamic>?) ?? const {};
            final siteId = (data['siteId'] as String?) ?? site.id;
            final siteName = (data['siteName'] as String?) ?? '';
            final location = (data['location'] as String?) ?? '';
            final projectCategory = (data['projectCategory'] as String?) ?? '';
            final status = (data['status'] as String?) ?? 'In Progress';

            final isDone = status.toLowerCase() == 'completed';
            final isHold = status.toLowerCase() == 'on hold' ||
                status.toLowerCase() == 'cancelled';

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: darkCardBg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: darkCardBg.withValues(alpha: 0.2),
                    blurRadius: 12,
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
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.location_city_rounded,
                          color: primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              siteName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ID: $siteId',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDone
                              ? Colors.green.withValues(alpha: 0.2)
                              : isHold
                                  ? Colors.orange.withValues(alpha: 0.2)
                                  : primaryColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isDone
                                ? const Color(0xFF4ADE80)
                                : isHold
                                    ? Colors.orange[300]
                                    : primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (location.isNotEmpty || projectCategory.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    const SizedBox(height: 10),
                    if (location.isNotEmpty)
                      _siteInfoRow(Icons.location_on_rounded, location),
                    if (projectCategory.isNotEmpty)
                      _siteInfoRow(Icons.category_rounded, projectCategory),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _siteInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFFCBD5E1)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFE2E8F0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: -0.3,
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
    IconData? icon,
  }) {
    final theme = Theme.of(context);
    final brandIconColor = AppTheme.getDarkAccent(theme.primaryColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: readOnly ? const Color(0xFFF1F5F9) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            readOnly: readOnly,
            validator: validator,
            style: const TextStyle(
              color: Color(0xFF0A183D),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: icon != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(icon, color: brandIconColor, size: 22),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
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
    IconData? icon,
  }) {
    final theme = Theme.of(context);
    final brandIconColor = AppTheme.getDarkAccent(theme.primaryColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            isExpanded: true,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(16),
            style: const TextStyle(
              color: Color(0xFF0A183D),
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: 'Select $label',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: icon != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(icon, color: brandIconColor, size: 22),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            items: items
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(item),
                  ),
                )
                .toList(),
            onChanged: onChanged,
            validator: (val) => val == null ? 'Please select $label' : null,
          ),
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
    final brandIconColor = AppTheme.getDarkAccent(theme.primaryColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    color: brandIconColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    date == null
                        ? 'Select $label'
                        : DateFormat('MMM d, yyyy').format(date),
                    style: TextStyle(
                      color: date == null
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF0A183D),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
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
        style: const TextStyle(color: Colors.orange, fontSize: 13),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, Color primaryColor) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveSiteDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: const Color(0xFF0A183D),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 6,
                shadowColor: primaryColor.withValues(alpha: 0.4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isSaving ? Icons.hourglass_top_rounded : Icons.save_rounded,
                    size: 20,
                    color: const Color(0xFF0A183D),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isSaving ? 'SAVING...' : 'SAVE SITE',
                    style: const TextStyle(
                      color: Color(0xFF0A183D),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _resetForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              ),
              elevation: 0,
            ),
            child: const Row(
              children: [
                Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'RESET',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveSiteDetails() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() => _isSaving = true);

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
                          foregroundColor: const Color(0xFF0A183D),
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
