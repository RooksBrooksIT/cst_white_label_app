import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/services/subscription_limit_service.dart';
import 'package:demo_cst/utils/app_theme.dart';

class ProjectSetupWizard extends StatefulWidget {
  const ProjectSetupWizard({super.key});

  @override
  State<ProjectSetupWizard> createState() => _ProjectSetupWizardState();
}

class _ProjectSetupWizardState extends State<ProjectSetupWizard>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  final PageController _pageController = PageController();
  late AnimationController _animationController;

  // Step 1: Site Details
  final _siteFormKey = GlobalKey<FormState>();
  final TextEditingController _siteNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  String? _siteProjectCategory;
  DateTime? _siteStartDate;
  DateTime? _siteEndDate;
  String? _siteStatus;

  // Step 2: Project Configuration
  final _projectFormKey = GlobalKey<FormState>();
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _ownerPhoneController = TextEditingController();
  final TextEditingController _amountPaidController = TextEditingController();
  final TextEditingController _projectBudgetController =
      TextEditingController();
  final TextEditingController _contractorNameController =
      TextEditingController();
  final TextEditingController _contractorBudgetController =
      TextEditingController();
  String? _projectSubCategory;
  String? _projectContract;
  String? _projectStage;
  String? _projectStatus;
  DateTime? _actualStartDate;
  DateTime? _actualEndDate;
  DateTime? _contractStartDate;
  DateTime? _contractEndDate;
  bool _isContractWork = false;

  // Step 3: Site Supervisor Map
  final _mapFormKey = GlobalKey<FormState>();
  String? _selectedSupervisorId;
  String? _selectedSupervisorName;
  String? _mapProjectStage;
  DateTime? _joinedDate;
  final TextEditingController _commentsController = TextEditingController();

  // Dropdown Data
  List<String> _categories = [];
  List<String> _subCategories = [];
  List<String> _contracts = [];
  List<String> _statuses = [];
  List<String> _projectStagesList = [];
  List<String> _contractors = [];
  List<Map<String, String>> _supervisors = [];
  bool _isLoadingDropdowns = true;

  bool _isSaving = false;
  bool _isGettingLocation = false;
  bool _isTermsAgreed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fetchDropdownData();
    _setupAmountListeners();
    _siteNameController.addListener(() {
      if (_projectNameController.text.isEmpty ||
          _siteNameController.text.startsWith(_projectNameController.text)) {
        _projectNameController.text = _siteNameController.text;
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _siteNameController.dispose();
    _locationController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _projectNameController.dispose();
    _ownerNameController.dispose();
    _ownerPhoneController.dispose();
    _amountPaidController.dispose();
    _projectBudgetController.dispose();
    _contractorNameController.dispose();
    _contractorBudgetController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  // -------------------- DATA FETCHING --------------------
  Future<void> _fetchDropdownData() async {
    setState(() => _isLoadingDropdowns = true);
    try {
      final results = await Future.wait([
        FirestoreService.getCollection('projectCategories').get(),
        FirestoreService.getCollection('projectSubCategories').get(),
        FirestoreService.getCollection('projectContracts').get(),
        FirestoreService.getCollection('projectStatus').get(),
        FirestoreService.getCollection('supervisor').get(),
        FirestoreService.getCollection('projectStages').get(),
        FirestoreService.getCollection('contractors').get(),
      ]);

      if (mounted) {
        setState(() {
          _categories = results[0].docs
              .map((doc) => doc['projectCategory']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList();

          _subCategories = results[1].docs
              .map((doc) => doc['projectSubCategory']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList();

          _contracts = results[2].docs
              .map((doc) => doc['projectContract']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList();

          _statuses = results[3].docs
              .map((doc) => (doc.data()['projectState'] ?? doc.data()['projectStatus'])?.toString().trim() ?? '')
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList();

          _projectStagesList = results[5].docs
              .map((doc) => doc['projectStage']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList();

          _contractors = results[6].docs
              .map((doc) => doc['contractorType']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList();

          _supervisors = results[4].docs.map((doc) {
            final data = doc.data();
            return {
              'id': (data['SupervisorId'] ?? doc.id).toString(),
              'name': data['FullName']?.toString() ?? 'Unknown',
            };
          }).toList();

          // Ensure supervisors are unique by ID
          final seenIds = <String>{};
          _supervisors.retainWhere((s) => seenIds.add(s['id']!));

          _isLoadingDropdowns = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching dropdown data: $e');
      if (mounted) {
        setState(() => _isLoadingDropdowns = false);
        _showErrorSnackBar('Failed to load dropdown data: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // -------------------- LOCATION --------------------
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
          _showErrorSnackBar('Location permissions are denied');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showErrorSnackBar(
          'Location permissions are permanently denied. Please enable them in App Settings.',
        );
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

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
              place.name,
              place.subLocality,
              place.locality,
              place.administrativeArea,
              place.country,
            ].where((p) => p != null && p.isNotEmpty).join(', ');
          }
        } catch (geocodingError) {
          debugPrint('Geocoding error (falling back to coordinates only): $geocodingError');
          address = 'Coordinates: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
        }
      }

      setState(() {
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
        if (_locationController.text.isEmpty || _locationController.text == 'Web Location') {
          _locationController.text = address;
        }
      });
    } catch (e) {
      _showErrorSnackBar('Error getting location: $e');
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  // -------------------- NAVIGATION & SAVE --------------------
  void _nextStep() {
    bool isValid = false;
    if (_currentStep == 0) {
      isValid = _siteFormKey.currentState?.validate() ?? false;
    } else if (_currentStep == 1) {
      isValid = _projectFormKey.currentState?.validate() ?? false;
    } else if (_currentStep == 2) {
      isValid = _mapFormKey.currentState?.validate() ?? false;
      if (isValid) {
        _saveAll();
      }
      return;
    }

    if (isValid && _currentStep < 2) {
      HapticFeedback.lightImpact();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
      _animationController.forward(from: 0);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      HapticFeedback.lightImpact();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _setupAmountListeners() {
    _amountPaidController.addListener(_updateBalanceAmount);
    _projectBudgetController.addListener(_updateBalanceAmount);
  }

  void _updateBalanceAmount() {
    setState(() {});
  }

  Future<String> _getNextId(
    String collection,
    String prefix,
    String? field,
  ) async {
    final snapshot = await FirestoreService.getCollection(
      collection,
    ).orderBy(FieldPath.documentId).get();
    int maxNum = 0;
    for (var doc in snapshot.docs) {
      final id = field != null ? (doc[field]?.toString() ?? '') : doc.id;
      if (id.startsWith(prefix)) {
        final numPart = int.tryParse(id.substring(prefix.length));
        if (numPart != null && numPart > maxNum) maxNum = numPart;
      }
    }
    return '$prefix${(maxNum + 1).toString().padLeft(3, '0')}';
  }

  Future<void> _saveAll({bool skipSupervisorMapping = false}) async {
    // Validate active subscription site limit
    final subValidation = await SubscriptionLimitService.canCreateSite();
    if (!subValidation.isAllowed) {
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

    if (!mounted) return;

    setState(() => _isSaving = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: AppTheme.primaryColor.value,
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              Text(
                skipSupervisorMapping
                    ? 'Saving project details...'
                    : 'Setting up your project...',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0A183D),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Please wait while we initialize services',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final siteId = await _getNextId('Site', 'ST', 'siteId');
      final projectId = await _getNextId('projects', 'PR', null);
      final siteDocId =
          '${siteId}_${_siteNameController.text.trim().replaceAll(' ', '')}';

      // Save Site
      final siteData = {
        'siteId': siteId,
        'siteName': _siteNameController.text.trim(),
        'location': _locationController.text.trim(),
        'latitude': double.tryParse(_latitudeController.text),
        'longitude': double.tryParse(_longitudeController.text),
        'projectCategory': _siteProjectCategory,
        'startDate': _siteStartDate != null
            ? DateFormat('yyyy-MM-dd').format(_siteStartDate!)
            : '',
        'endDate': _siteEndDate != null
            ? DateFormat('yyyy-MM-dd').format(_siteEndDate!)
            : '',
        'status': _siteStatus ?? 'Ongoing',
        'createdAt': FieldValue.serverTimestamp(),
      };
      await FirestoreService.getCollection('Site').doc(siteDocId).set(siteData);

      // Save Project
      final projectData = {
        'projectName': _projectNameController.text.trim(),
        'ownerName': _ownerNameController.text.trim(),
        'ownerPhoneNumber': _ownerPhoneController.text.trim(),
        'amountPaid': double.tryParse(_amountPaidController.text) ?? 0,
        'amountSpent': 0.0,
        'amountBalance': double.tryParse(_amountPaidController.text) ?? 0,
        'projectBudget': double.tryParse(_projectBudgetController.text) ?? 0,
        'projectCategory': _siteProjectCategory ?? '',
        'projectSubCategory': _projectSubCategory ?? '',
        'projectContract': _projectContract ?? '',
        'projectStage': _projectStage ?? '',
        'currentStatus':
            _projectStatus ?? (_statuses.isNotEmpty ? _statuses.first : ''),
        'plannedStartDate': _siteStartDate != null
            ? Timestamp.fromDate(_siteStartDate!)
            : Timestamp.now(),
        'plannedEndDate': _siteEndDate != null
            ? Timestamp.fromDate(_siteEndDate!)
            : null,
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
        'contractorName': _isContractWork
            ? _contractorNameController.text
            : null,
        'contractorBudget': _isContractWork
            ? (double.tryParse(_contractorBudgetController.text) ?? 0)
            : null,
        'siteId': siteDocId,
        'createdAt': FieldValue.serverTimestamp(),
        'projectType': _siteProjectCategory ?? '',
        'status':
            _projectStatus ?? (_statuses.isNotEmpty ? _statuses.first : ''),
      };
      await FirestoreService.getCollection(
        'projects',
      ).doc(projectId).set(projectData);

      // Initialize Expenses
      await FirestoreService.getCollection(
        'totalSiteExpensesPerDay',
      ).doc(siteDocId).set({
        'siteId': siteDocId,
        'totalMgrExpense': 0.0,
        'totalOrgExpense': 0.0,
        'totalSiteExpense': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!skipSupervisorMapping && _selectedSupervisorId != null) {
        // Map Supervisor
        final supervisorMapId =
            '${siteId}_${_locationController.text.trim().replaceAll(' ', '')}_$_selectedSupervisorId';
        await FirestoreService.getCollection(
          'siteSupervisorMap',
        ).doc(supervisorMapId).set({
          'site': siteDocId,
          'siteId': siteId,
          'siteName': _siteNameController.text.trim(),
          'projectName': _projectNameController.text.trim(),
          'supervisor': _selectedSupervisorName,
          'Supervisor ID': _selectedSupervisorId,
          'supervisorId': _selectedSupervisorId,
          'location': _locationController.text.trim(),
          'projectStage': _mapProjectStage ?? _projectStage,
          'siteComments': _commentsController.text.trim(),
          'joinedOn': _joinedDate != null
              ? DateFormat('yyyy-MM-dd').format(_joinedDate!)
              : '',
          'startDate': _siteStartDate != null
              ? DateFormat('yyyy-MM-dd').format(_siteStartDate!)
              : '',
          'endDate': _siteEndDate != null
              ? DateFormat('yyyy-MM-dd').format(_siteEndDate!)
              : '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog
        _showSuccessDialog(skippedAssignment: skipSupervisorMapping);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showErrorSnackBar('Error saving project: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSuccessDialog({bool skippedAssignment = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF10B981),
                size: 40,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Project Created!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A183D),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your project and site architecture have been configured successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildSuccessCheckRow('Site created & registered'),
                  const SizedBox(height: 8),
                  _buildSuccessCheckRow('Project configuration saved'),
                  const SizedBox(height: 8),
                  _buildSuccessCheckRow(
                    skippedAssignment
                        ? 'Supervisor assignment skipped'
                        : 'Supervisor mapped to site',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor.value,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Done & Return to Dashboard',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessCheckRow(String text) {
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
        ),
      ],
    );
  }

  // -------------------- MAIN BUILD --------------------
  @override
  Widget build(BuildContext context) {
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColor,
      builder: (context, primaryColor, _) {
        final darkAccent = AppTheme.getDarkAccent(primaryColor);

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            elevation: 0,
            titleSpacing: 16,
            backgroundColor: primaryColor,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, darkAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            leading: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                tooltip: 'Back',
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Project Setup Wizard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  _currentStep == 0
                      ? 'Step 1 of 3 • Site Details'
                      : _currentStep == 1
                          ? 'Step 2 of 3 • Project Configuration'
                          : 'Step 3 of 3 • Supervisor Assignment',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              if (_currentStep == 2)
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: TextButton(
                    onPressed: _isSaving
                        ? null
                        : () => _saveAll(skipSupervisorMapping: true),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                    ),
                    child: const Text(
                      'Skip Step',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 4),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 840),
                child: Column(
                  children: [
                    // Persistent Step Indicator
                    _buildStepperBar(primaryColor),

                    // Step Pages
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        onPageChanged: (index) =>
                            setState(() => _currentStep = index),
                        children: [
                          _buildSiteStep(primaryColor),
                          _buildProjectStep(primaryColor),
                          _buildMapStep(primaryColor),
                        ],
                      ),
                    ),

                    // Sticky Bottom Navigation Buttons
                    if (!isKeyboardVisible)
                      _buildBottomNavBar(primaryColor, darkAccent),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // -------------------- STEPPER BAR --------------------
  Widget _buildStepperBar(Color primaryColor) {
    final steps = [
      {'title': 'Site Details', 'icon': Icons.location_on_rounded},
      {'title': 'Configuration', 'icon': Icons.settings_rounded},
      {'title': 'Supervisor', 'icon': Icons.person_pin_rounded},
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            final stepIndex = index ~/ 2;
            final isPassed = stepIndex < _currentStep;
            return Expanded(
              child: Container(
                height: 2.5,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: isPassed
                      ? primaryColor
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }

          final stepIdx = index ~/ 2;
          final isActive = stepIdx == _currentStep;
          final isCompleted = stepIdx < _currentStep;

          return InkWell(
            onTap: () {
              if (stepIdx < _currentStep) {
                _pageController.animateToPage(
                  stepIdx,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? const Color(0xFF10B981)
                        : isActive
                            ? primaryColor
                            : const Color(0xFFF1F5F9),
                    border: Border.all(
                      color: isCompleted
                          ? const Color(0xFF10B981)
                          : isActive
                              ? primaryColor
                              : const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 16,
                          )
                        : Icon(
                            steps[stepIdx]['icon'] as IconData,
                            color: isActive
                                ? Colors.white
                                : const Color(0xFF94A3B8),
                            size: 15,
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  steps[stepIdx]['title'] as String,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight:
                        isActive ? FontWeight.w800 : FontWeight.w600,
                    color: isCompleted
                        ? const Color(0xFF0F172A)
                        : isActive
                            ? primaryColor
                            : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // -------------------- STEP 1: SITE DETAILS --------------------
  Widget _buildSiteStep(Color primaryColor) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Form(
        key: _siteFormKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeader(
              'Site Information',
              'Register the physical location, GPS coordinates, and timeline for the new site.',
            ),
            const SizedBox(height: 20),
            _buildSectionCard(
              title: 'Basic Site Information',
              subtitle: 'Identify your site and its physical address',
              icon: Icons.domain_rounded,
              primaryColor: primaryColor,
              children: [
                _buildInputField(
                  controller: _siteNameController,
                  label: 'Site Name',
                  hint: 'e.g. Skyline Heights Phase 1',
                  icon: Icons.apartment_rounded,
                  isRequired: true,
                  primaryColor: primaryColor,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Site name is required' : null,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: _locationController,
                  label: 'Location Address',
                  hint: 'e.g. 42 Main Avenue, North District',
                  icon: Icons.location_on_rounded,
                  isRequired: true,
                  primaryColor: primaryColor,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Location address is required' : null,
                ),
              ],
            ),
            _buildSectionCard(
              title: 'Geolocation Coordinates',
              subtitle: 'GPS precision coordinates for field supervisor check-ins',
              icon: Icons.satellite_alt_rounded,
              primaryColor: primaryColor,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildInputField(
                        controller: _latitudeController,
                        label: 'Latitude',
                        hint: '0.000000',
                        icon: Icons.explore_outlined,
                        readOnly: true,
                        primaryColor: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInputField(
                        controller: _longitudeController,
                        label: 'Longitude',
                        hint: '0.000000',
                        icon: Icons.explore_outlined,
                        readOnly: true,
                        primaryColor: primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isGettingLocation ? null : _getCurrentLocation,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: primaryColor, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      foregroundColor: primaryColor,
                      backgroundColor: primaryColor.withValues(alpha: 0.05),
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
                        : Icon(Icons.my_location_rounded, size: 18, color: primaryColor),
                    label: Text(
                      _isGettingLocation
                          ? 'Acquiring GPS Position...'
                          : 'Fetch Current Device Location',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            _buildSectionCard(
              title: 'Site Timeline & Initial Status',
              subtitle: 'Estimated active operation period and status',
              icon: Icons.calendar_month_rounded,
              primaryColor: primaryColor,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildDateField(
                        'Start Date',
                        _siteStartDate,
                        (d) => setState(() => _siteStartDate = d),
                        primaryColor: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDateField(
                        'End Date',
                        _siteEndDate,
                        (d) => setState(() => _siteEndDate = d),
                        primaryColor: primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDropdownField(
                  'Site Status',
                  _siteStatus,
                  _statuses.isNotEmpty
                      ? _statuses
                      : ['Planning', 'Ongoing', 'On Hold', 'Completed'],
                  (v) => setState(() => _siteStatus = v),
                  isLoading: _isLoadingDropdowns,
                  primaryColor: primaryColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // -------------------- STEP 2: PROJECT CONFIGURATION --------------------
  Widget _buildProjectStep(Color primaryColor) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Form(
        key: _projectFormKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeader(
              'Project Configuration',
              'Set up project scope, budget allocation, owner contact, and classification.',
            ),
            const SizedBox(height: 20),
            _buildSectionCard(
              title: 'Core Project Information',
              subtitle: 'Identity and client / owner details',
              icon: Icons.engineering_rounded,
              primaryColor: primaryColor,
              children: [
                _buildInputField(
                  controller: _projectNameController,
                  label: 'Project Name',
                  hint: 'e.g. Skyline Towers Commercial Block',
                  icon: Icons.business_center_rounded,
                  isRequired: true,
                  primaryColor: primaryColor,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Project name is required'
                      : null,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: _ownerNameController,
                  label: 'Owner / Client Name',
                  hint: 'e.g. John Doe',
                  icon: Icons.person_outline_rounded,
                  isRequired: true,
                  primaryColor: primaryColor,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Owner name is required'
                      : null,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: _ownerPhoneController,
                  label: 'Owner Phone Number',
                  hint: '10-digit mobile number',
                  icon: Icons.phone_android_rounded,
                  keyboardType: TextInputType.phone,
                  isRequired: true,
                  primaryColor: primaryColor,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Phone number is required';
                    if (v.trim().length != 10) return 'Must be exactly 10 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Customer Login Info Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: Color(0xFF059669),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Automatic Customer Portal Access',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF065F46),
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'The Owner Name and Phone Number will be automatically configured as the credentials for customer login portal.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF047857),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _buildFinancialSection(primaryColor),
            _buildSectionCard(
              title: 'Classification & Scope',
              subtitle: 'Categorization and contractual terms',
              icon: Icons.category_rounded,
              primaryColor: primaryColor,
              children: [
                _buildDropdownField(
                  'Project Category',
                  _siteProjectCategory,
                  _categories.isNotEmpty
                      ? _categories
                      : ['Residential', 'Commercial', 'Industrial', 'Infrastructure'],
                  (v) => setState(() => _siteProjectCategory = v),
                  isLoading: _isLoadingDropdowns,
                  primaryColor: primaryColor,
                ),
                const SizedBox(height: 16),
                _buildDropdownField(
                  'Sub Category',
                  _projectSubCategory,
                  _subCategories.isNotEmpty
                      ? _subCategories
                      : ['New Construction', 'Renovation', 'Expansion', 'Interior Fitout'],
                  (v) => setState(() => _projectSubCategory = v),
                  isLoading: _isLoadingDropdowns,
                  primaryColor: primaryColor,
                ),
                const SizedBox(height: 16),
                _buildDropdownField(
                  'Contract Type',
                  _projectContract,
                  _contracts.isNotEmpty
                      ? _contracts
                      : ['Turnkey', 'Item Rate', 'Lump Sum', 'Labor Contract'],
                  (v) => setState(() => _projectContract = v),
                  isLoading: _isLoadingDropdowns,
                  primaryColor: primaryColor,
                ),
                const SizedBox(height: 16),
                _buildDropdownField(
                  'Project Stage',
                  _projectStage,
                  _projectStagesList.isNotEmpty
                      ? _projectStagesList
                      : ['Planning', 'Foundation', 'Structure', 'Finishing', 'Handover'],
                  (v) => setState(() => _projectStage = v),
                  isLoading: _isLoadingDropdowns,
                  primaryColor: primaryColor,
                ),
                const SizedBox(height: 16),
                _buildDropdownField(
                  'Current Status',
                  _projectStatus,
                  _statuses.isNotEmpty
                      ? _statuses
                      : ['Active', 'In Progress', 'Pending Approval', 'Completed'],
                  (v) => setState(() => _projectStatus = v),
                  isLoading: _isLoadingDropdowns,
                  primaryColor: primaryColor,
                ),
              ],
            ),
            _buildSectionCard(
              title: 'Execution Timeline',
              subtitle: 'Track actual commencement and completion dates',
              icon: Icons.date_range_rounded,
              primaryColor: primaryColor,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildDateField(
                        'Actual Start Date',
                        _actualStartDate,
                        (d) => setState(() => _actualStartDate = d),
                        primaryColor: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDateField(
                        'Actual End Date',
                        _actualEndDate,
                        (d) => setState(() => _actualEndDate = d),
                        primaryColor: primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            _buildContractWorkSection(primaryColor),
          ],
        ),
      ),
    );
  }

  // Financial Section with interactive progress bar
  Widget _buildFinancialSection(Color primaryColor) {
    final double budget = double.tryParse(_projectBudgetController.text) ?? 0;
    final double paid = double.tryParse(_amountPaidController.text) ?? 0;
    final double balance = budget - paid;
    final double percentage = budget > 0 ? (paid / budget).clamp(0.0, 1.0) : 0;

    return _buildSectionCard(
      title: 'Financial & Budgeting',
      subtitle: 'Manage overall project budget and initial advance',
      icon: Icons.account_balance_wallet_rounded,
      primaryColor: primaryColor,
      children: [
        _buildInputField(
          controller: _projectBudgetController,
          label: 'Total Project Budget (₹)',
          hint: 'e.g. 5000000',
          icon: Icons.currency_rupee_rounded,
          keyboardType: TextInputType.number,
          primaryColor: primaryColor,
          validator: (v) {
            if (v != null && v.isNotEmpty) {
              if (double.tryParse(v) == null) return 'Enter a valid number';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildInputField(
          controller: _amountPaidController,
          label: 'Initial Amount Paid / Advance (₹)',
          hint: 'e.g. 1000000',
          icon: Icons.payments_outlined,
          keyboardType: TextInputType.number,
          primaryColor: primaryColor,
          validator: (v) {
            if (v != null && v.isNotEmpty) {
              if (double.tryParse(v) == null) return 'Enter a valid number';
            }
            return null;
          },
        ),
        if (budget > 0) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Payment Coverage',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${(percentage * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 13,
                        color: primaryColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _buildFinancialMiniPill(
                      'Budget',
                      '₹${NumberFormat('#,##,###').format(budget)}',
                      const Color(0xFF3B82F6),
                    ),
                    const SizedBox(width: 8),
                    _buildFinancialMiniPill(
                      'Paid',
                      '₹${NumberFormat('#,##,###').format(paid)}',
                      const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 8),
                    _buildFinancialMiniPill(
                      'Remaining',
                      '₹${NumberFormat('#,##,###').format(balance)}',
                      balance < 0
                          ? const Color(0xFFEF4444)
                          : const Color(0xFFF59E0B),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFinancialMiniPill(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Contract Work Section
  Widget _buildContractWorkSection(Color primaryColor) {
    return _buildSectionCard(
      title: 'Sub-contractor Assignment',
      subtitle: 'Specify if project execution is outsourced to a contractor',
      icon: Icons.handyman_rounded,
      primaryColor: primaryColor,
      trailing: Switch(
        value: _isContractWork,
        onChanged: (v) => setState(() => _isContractWork = v),
        activeTrackColor: primaryColor.withValues(alpha: 0.6),
        activeThumbColor: primaryColor,
      ),
      children: [
        if (!_isContractWork)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Toggle the switch if this project involves third-party contractor management.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5),
            ),
          ),
        if (_isContractWork) ...[
          _buildDropdownField(
            'Contractor Name / Agency',
            _contractorNameController.text.isEmpty
                ? null
                : _contractorNameController.text,
            _contractors.isNotEmpty
                ? _contractors
                : ['General Contractor', 'Civil Contractor', 'Electrical Contractor', 'Turnkey Agency'],
            (v) => setState(() => _contractorNameController.text = v ?? ''),
            isLoading: _isLoadingDropdowns,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 16),
          _buildInputField(
            controller: _contractorBudgetController,
            label: 'Contractor Allocated Budget (₹)',
            hint: 'e.g. 2500000',
            icon: Icons.account_balance_wallet_outlined,
            keyboardType: TextInputType.number,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDateField(
                  'Contract Start',
                  _contractStartDate,
                  (d) => setState(() => _contractStartDate = d),
                  primaryColor: primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateField(
                  'Contract End',
                  _contractEndDate,
                  (d) => setState(() => _contractEndDate = d),
                  primaryColor: primaryColor,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // -------------------- STEP 3: SUPERVISOR ASSIGNMENT --------------------
  Widget _buildMapStep(Color primaryColor) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Form(
        key: _mapFormKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeader(
              'Supervisor Assignment',
              'Assign a certified on-site supervisor and review overall project readiness.',
            ),
            const SizedBox(height: 20),
            _buildSectionCard(
              title: 'On-Site Field Supervisor',
              subtitle: 'Select from available registered supervisor profiles',
              icon: Icons.badge_rounded,
              primaryColor: primaryColor,
              children: [
                _buildDropdownField(
                  'Select Supervisor',
                  _selectedSupervisorId,
                  _supervisors.map((s) => s['id']!).toList(),
                  (id) {
                    final sup = _supervisors.firstWhere((s) => s['id'] == id);
                    setState(() {
                      _selectedSupervisorId = id;
                      _selectedSupervisorName = sup['name'];
                    });
                  },
                  displayItems: _supervisors
                      .map((s) => '${s['name']} (${s['id']})')
                      .toList(),
                  isLoading: _isLoadingDropdowns,
                  primaryColor: primaryColor,
                  validator: (v) =>
                      v == null ? 'Please select a supervisor (or skip)' : null,
                ),
              ],
            ),
            _buildSectionCard(
              title: 'Assignment Parameters',
              subtitle: 'Initial stage handoff and joining timestamp',
              icon: Icons.assignment_turned_in_rounded,
              primaryColor: primaryColor,
              children: [
                _buildDropdownField(
                  'Initial Supervision Stage',
                  _mapProjectStage ?? _projectStage,
                  _projectStagesList.isNotEmpty
                      ? _projectStagesList
                      : ['Planning', 'Foundation', 'Structure', 'Finishing', 'Handover'],
                  (v) => setState(() => _mapProjectStage = v),
                  isLoading: _isLoadingDropdowns,
                  primaryColor: primaryColor,
                ),
                const SizedBox(height: 16),
                _buildDateField(
                  'Supervisor Joined Date',
                  _joinedDate,
                  (d) => setState(() => _joinedDate = d),
                  primaryColor: primaryColor,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: _commentsController,
                  label: 'Site Brief / Notes (Optional)',
                  hint: 'Enter any specific site instructions or comments...',
                  icon: Icons.notes_rounded,
                  maxLines: 3,
                  primaryColor: primaryColor,
                ),
              ],
            ),
            _buildSummaryCard(primaryColor),
          ],
        ),
      ),
    );
  }

  // Summary Card
  Widget _buildSummaryCard(Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: Color(0xFF10B981),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Project Architecture Summary',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A183D),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Confirm details before initializing database entries',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _buildSummaryRow('Site Name', _siteNameController.text),
                _buildSummaryRow('Project Name', _projectNameController.text),
                _buildSummaryRow('Owner / Client', _ownerNameController.text),
                _buildSummaryRow('Assigned Supervisor', _selectedSupervisorName ?? 'Not Assigned'),
                _buildSummaryRow('Current Stage', _projectStage ?? 'Planning'),
                _buildSummaryRow(
                  'Project Budget',
                  _projectBudgetController.text.isNotEmpty
                      ? '₹${_projectBudgetController.text}'
                      : 'Not Set',
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 22,
                  width: 22,
                  child: Checkbox(
                    value: _isTermsAgreed,
                    onChanged: (v) => setState(() => _isTermsAgreed = v ?? false),
                    activeColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isTermsAgreed = !_isTermsAgreed),
                    child: const Text(
                      'I confirm that all site and project parameters have been reviewed and comply with the project standards.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            (value == null || value.trim().isEmpty) ? '—' : value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------- REUSABLE FORM COMPONENTS --------------------
  Widget _buildStepHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0A183D),
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    String? subtitle,
    required IconData icon,
    required List<Widget> children,
    required Color primaryColor,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0A183D),
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    required Color primaryColor,
    bool isRequired = false,
    bool readOnly = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Color(0xFF334155),
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
          ],
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.normal,
            ),
            prefixIcon: Icon(icon, size: 20, color: primaryColor),
            filled: true,
            fillColor: readOnly ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              borderSide: BorderSide(color: primaryColor, width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(
    String label,
    DateTime? date,
    Function(DateTime) onSelected, {
    required Color primaryColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 7),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: primaryColor,
                      onPrimary: Colors.white,
                      surface: Colors.white,
                      onSurface: const Color(0xFF0F172A),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) onSelected(picked);
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: primaryColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    date == null
                        ? 'Select date'
                        : DateFormat('dd MMM yyyy').format(date),
                    style: TextStyle(
                      color: date == null
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF0F172A),
                      fontWeight:
                          date != null ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 13.5,
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

  Widget _buildDropdownField(
    String label,
    String? value,
    List<String> items,
    Function(String?) onChanged, {
    List<String>? displayItems,
    bool isLoading = false,
    required Color primaryColor,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: isLoading
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  )
                : DropdownButton<String>(
                    value: (value != null && items.contains(value)) ? value : null,
                    isExpanded: true,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF64748B),
                    ),
                    hint: Text(
                      'Select $label',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13.5,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    items: List.generate(
                      items.length,
                      (i) => DropdownMenuItem(
                        value: items[i],
                        child: Text(
                          displayItems != null ? displayItems[i] : items[i],
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    onChanged: onChanged,
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
          ),
        ),
      ],
    );
  }

  // Sticky Bottom Navigation Buttons
  Widget _buildBottomNavBar(Color primaryColor, Color darkAccent) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            Expanded(
              flex: 1,
              child: OutlinedButton.icon(
                onPressed: _previousStep,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                  foregroundColor: const Color(0xFF475569),
                ),
              ),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, darkAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ElevatedButton.icon(
                onPressed: (_isSaving || (_currentStep == 2 && !_isTermsAgreed))
                    ? null
                    : _nextStep,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _currentStep == 2
                            ? Icons.check_circle_rounded
                            : Icons.arrow_forward_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                label: Text(
                  _isSaving
                      ? 'Saving Project...'
                      : (_currentStep == 2
                          ? 'Complete & Create Project'
                          : 'Continue to ${_currentStep == 0 ? 'Project Setup' : 'Supervisor'}'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
