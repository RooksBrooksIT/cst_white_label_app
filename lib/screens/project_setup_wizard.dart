import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_text_field.dart';

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
          if (_categories.isEmpty) {
            _categories = [
              'Residential',
              'Commercial',
              'Industrial',
              'Infrastructure',
            ];
          }

          _subCategories = results[1].docs
              .map((doc) => doc['projectSubCategory']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList();
          if (_subCategories.isEmpty) {
            _subCategories = [
              'New Construction',
              'Renovation',
              'Expansion',
              'Maintenance',
            ];
          }

          _contracts = results[2].docs
              .map((doc) => doc['projectContract']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList();
          if (_contracts.isEmpty) {
            _contracts = [
              'Fixed Price',
              'Cost Plus',
              'Unit Price',
              'Time & Materials',
            ];
          }

          _statuses = results[3].docs
              .map((doc) => doc['projectState']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList();

          _projectStagesList = results[5].docs
              .map((doc) => doc['projectStage']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList();

          _contractors = results[6].docs
              .map((doc) => doc['contractorName']?.toString() ?? '')
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

          if (_statuses.isEmpty) {
            _statuses = [
              'Not Started',
              'Ongoing',
              'On Hold',
              'Completed',
              'Cancelled',
            ];
          }

          if (_projectStagesList.isEmpty) {
            _projectStagesList = [
              'Planning',
              'Foundation',
              'Structure',
              'Finishing',
              'Handover',
            ];
          }

          if (_contractors.isEmpty) {
            _contractors = [
              'General Contractor',
              'Sub Contractor',
              'Independent',
            ];
          }

          _isLoadingDropdowns = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching dropdown data: $e');
      if (mounted) {
        setState(() => _isLoadingDropdowns = false);
        _showErrorSnackBar('Failed to load data. Please try again.');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // -------------------- LOCATION --------------------
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

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String address = [
          place.name,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.country,
        ].where((p) => p != null && p.isNotEmpty).join(', ');

        setState(() {
          _latitudeController.text = position.latitude.toStringAsFixed(6);
          _longitudeController.text = position.longitude.toStringAsFixed(6);
          _locationController.text = address;
        });
      }
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
      if (isValid) _saveAll();
      return;
    }

    if (isValid && _currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
      _animationController.forward(from: 0);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _setupAmountListeners() {
    _amountPaidController.addListener(_updateBalanceAmount);
  }

  void _updateBalanceAmount() {
    // In the wizard, spent is always 0 for new projects, so balance = paid
    // But we keep the logic consistent with project_screen.dart
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
    setState(() => _isSaving = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              skipSupervisorMapping
                  ? 'Saving project details...'
                  : 'Setting up your project...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
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
        'currentStatus': _projectStatus ?? 'Planning',
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
        'status': _projectStatus ?? 'Planning',
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

      if (!skipSupervisorMapping) {
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

      Navigator.of(context).pop(); // Close loading dialog

      if (mounted) {
        _showSuccessDialog(skippedAssignment: skipSupervisorMapping);
      }
    } catch (e) {
      Navigator.of(context).pop();
      _showErrorSnackBar('Error saving: $e');
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
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade400, size: 32),
            const SizedBox(width: 12),
            const Text('Success!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your project has been successfully configured.'),
            const SizedBox(height: 8),
            Text(
              '✓ Site created\n✓ Project configured${skippedAssignment ? '' : '\n✓ Supervisor assigned'}',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.green.shade700),
            child: const Text('DONE'),
          ),
        ],
      ),
    );
  }

  // -------------------- UI BUILD --------------------
  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Project Setup Wizard',
      onBack: () => Navigator.pop(context),
      actions: [
        if (_currentStep == 2)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: _isSaving
                  ? null
                  : () => _saveAll(skipSupervisorMapping: true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text(
                'Skip',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
      ],
      body: Column(
        children: [
          _buildModernStepIndicator(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) => setState(() => _currentStep = index),
              children: [
                _buildSiteStep(),
                _buildProjectStep(),
                _buildMapStep(),
              ],
            ),
          ),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  // -------------------- STEP INDICATOR --------------------
  Widget _buildModernStepIndicator() {
    final steps = [
      {'icon': Icons.location_on_rounded, 'title': 'Site'},
      {'icon': Icons.work_rounded, 'title': 'Project'},
      {'icon': Icons.people_rounded, 'title': 'Assignment'},
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Background Line
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  children: List.generate(steps.length - 1, (index) {
                    return Expanded(
                      child: Container(
                        height: 2,
                        color: index < _currentStep
                            ? Theme.of(context).primaryColor
                            : Colors.grey.shade300,
                      ),
                    );
                  }),
                ),
              ),
              // Step Circles
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(steps.length, (index) {
                  final isActive = index <= _currentStep;
                  final isCompleted = index < _currentStep;

                  return Expanded(
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isActive
                                ? LinearGradient(
                                    colors: [
                                      Theme.of(context).primaryColor,
                                      Theme.of(
                                        context,
                                      ).primaryColor.withOpacity(0.7),
                                    ],
                                  )
                                : null,
                            color: !isActive ? Colors.grey.shade300 : null,
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: Theme.of(
                                        context,
                                      ).primaryColor.withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: isCompleted
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 24,
                                  )
                                : Icon(
                                    steps[index]['icon'] as IconData,
                                    color: isActive
                                        ? Colors.white
                                        : Colors.grey.shade600,
                                    size: 24,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          steps[index]['title'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? Theme.of(context).primaryColor
                                : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.05)],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: OutlinedButton.icon(
                onPressed: _previousStep,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.white.withOpacity(0.9),
                ),
              ),
            )
          else
            const SizedBox(width: 100),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: (_isSaving || (_currentStep == 2 && !_isTermsAgreed))
                  ? null
                  : _nextStep,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _currentStep == 2
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                      size: 18,
                    ),
              label: Text(
                _isSaving
                    ? 'Processing...'
                    : (_currentStep == 2 ? 'Complete' : 'Continue'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------- STEP 1: SITE DETAILS --------------------
  Widget _buildSiteStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Form(
        key: _siteFormKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          children: [
            _buildStepHeader(
              'Site Information',
              'Enter the basic details of your site',
            ),
            const SizedBox(height: 24),
            _buildSectionCard(
              title: 'Basic Information',
              subtitle: 'Identify your site and its physical location',
              icon: Icons.info_outline_rounded,
              children: [
                GlassTextField(
                  controller: _siteNameController,
                  label: 'Site Name',
                  icon: Icons.place_rounded,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Site name is required' : null,
                ),
                const SizedBox(height: 16),
                GlassTextField(
                  controller: _locationController,
                  label: 'Location Address',
                  icon: Icons.location_on_rounded,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Location is required' : null,
                ),
              ],
            ),
            _buildSectionCard(
              title: 'Geolocation',
              subtitle: 'Precision coordinates for site tracking',
              icon: Icons.map_rounded,
              children: [
                GlassTextField(
                  controller: _latitudeController,
                  label: 'Latitude',
                  icon: Icons.map_rounded,
                  readOnly: true,
                ),
                const SizedBox(height: 16),
                GlassTextField(
                  controller: _longitudeController,
                  label: 'Longitude',
                  icon: Icons.map_rounded,
                  readOnly: true,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isGettingLocation ? null : _getCurrentLocation,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(
                        color: Theme.of(context).primaryColor.withOpacity(0.5),
                      ),
                    ),
                    icon: _isGettingLocation
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.my_location_rounded,
                            color: Theme.of(context).primaryColor,
                          ),
                    label: Text(
                      _isGettingLocation
                          ? 'Getting location...'
                          : 'Get Current Location',
                      style: TextStyle(color: Theme.of(context).primaryColor),
                    ),
                  ),
                ),
              ],
            ),
            _buildSectionCard(
              title: 'Project Timeline',
              subtitle: 'Estimated start and end dates for the site',
              icon: Icons.calendar_today_rounded,
              children: [
                _buildDateField(
                  'Start Date',
                  _siteStartDate,
                  (d) => setState(() => _siteStartDate = d),
                ),
                const SizedBox(height: 16),
                _buildDateField(
                  'End Date',
                  _siteEndDate,
                  (d) => setState(() => _siteEndDate = d),
                ),
                const SizedBox(height: 16),
                _buildDropdownField(
                  'Site Status',
                  _siteStatus,
                  _statuses,
                  (v) => setState(() => _siteStatus = v),
                  isLoading: _isLoadingDropdowns,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // -------------------- STEP 2: PROJECT CONFIGURATION --------------------
  Widget _buildProjectStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Form(
        key: _projectFormKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          children: [
            _buildStepHeader(
              'Project Configuration',
              'Define project scope, financial details, and timeline',
            ),
            const SizedBox(height: 24),
            _buildSectionCard(
              title: 'Core Details',
              subtitle: 'Basic information about the project and its owner',
              icon: Icons.work_outline_rounded,
              children: [
                GlassTextField(
                  controller: _projectNameController,
                  label: 'Project Name',
                  icon: Icons.work_rounded,
                  validator: (v) => v == null || v.isEmpty
                      ? 'Project name is required'
                      : null,
                ),
                const SizedBox(height: 16),
                GlassTextField(
                  controller: _ownerNameController,
                  label: 'Owner Name',
                  icon: Icons.person_rounded,
                ),
                const SizedBox(height: 16),
                GlassTextField(
                  controller: _ownerPhoneController,
                  label: 'Owner Phone',
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                  // maxLength: 10,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Phone is required';
                    if (v.trim().length != 10) return 'Must be 10 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Customer Login Info Note
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor.withOpacity(0.1),
                        Theme.of(context).primaryColor.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_person_outlined,
                          color: Theme.of(context).primaryColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Customer Login Info',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'The Owner Name and Phone Number will be used as the username and password for the Customer Login.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                                height: 1.3,
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
            _buildFinancialSection(),
            _buildSectionCard(
              title: 'Classification',
              subtitle: 'Categorize the project for better reporting',
              icon: Icons.class_rounded,
              children: [
                _buildDropdownField(
                  'Project Category',
                  _siteProjectCategory,
                  _categories,
                  (v) => setState(() => _siteProjectCategory = v),
                  isLoading: _isLoadingDropdowns,
                ),
                const SizedBox(height: 16),
                _buildDropdownField(
                  'Sub Category',
                  _projectSubCategory,
                  _subCategories,
                  (v) => setState(() => _projectSubCategory = v),
                  isLoading: _isLoadingDropdowns,
                ),
                const SizedBox(height: 16),
                _buildDropdownField(
                  'Contract Type',
                  _projectContract,
                  _contracts,
                  (v) => setState(() => _projectContract = v),
                  isLoading: _isLoadingDropdowns,
                ),
                const SizedBox(height: 16),
                _buildDropdownField(
                  'Project Stage',
                  _projectStage,
                  _projectStagesList,
                  (v) => setState(() => _projectStage = v),
                  isLoading: _isLoadingDropdowns,
                ),
                const SizedBox(height: 16),
                _buildDropdownField(
                  'Current Status',
                  _projectStatus,
                  _statuses,
                  (v) => setState(() => _projectStatus = v),
                  isLoading: _isLoadingDropdowns,
                ),
              ],
            ),
            _buildSectionCard(
              title: 'Project Timeline',
              subtitle: 'Set the key dates for project execution',
              icon: Icons.calendar_today_rounded,
              children: [
                _buildDateField(
                  'Actual Start',
                  _actualStartDate,
                  (d) => setState(() => _actualStartDate = d),
                ),
                const SizedBox(height: 16),
                _buildDateField(
                  'Actual End',
                  _actualEndDate,
                  (d) => setState(() => _actualEndDate = d),
                ),
              ],
            ),
            _buildContractWorkSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialSection() {
    final double budget = double.tryParse(_projectBudgetController.text) ?? 0;
    final double paid = double.tryParse(_amountPaidController.text) ?? 0;
    final double balance = budget - paid;
    final double percentage = budget > 0 ? (paid / budget).clamp(0.0, 1.0) : 0;

    return _buildSectionCard(
      title: 'Financial Information',
      subtitle: 'Manage budget and payment status',
      icon: Icons.account_balance_wallet_rounded,
      children: [
        GlassTextField(
          controller: _projectBudgetController,
          label: 'Project Budget (₹)',
          icon: Icons.account_balance_wallet_rounded,
          keyboardType: TextInputType.number,
          onChanged: (v) => setState(() {}),
          validator: (v) {
            if (v != null && v.isNotEmpty) {
              if (double.tryParse(v) == null) return 'Invalid amount';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        GlassTextField(
          controller: _amountPaidController,
          label: 'Amount Paid (₹)',
          icon: Icons.currency_rupee_rounded,
          keyboardType: TextInputType.number,
          onChanged: (v) => setState(() {}),
          validator: (v) {
            if (v != null && v.isNotEmpty) {
              if (double.tryParse(v) == null) return 'Invalid amount';
            }
            return null;
          },
        ),
        if (budget > 0) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Payment Progress',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${(percentage * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildFinancialMiniStat(
                      'Balance',
                      '₹${NumberFormat('#,##,###').format(balance)}',
                      balance < 0 ? Colors.red.shade300 : Colors.green.shade300,
                    ),
                    const SizedBox(width: 16),
                    _buildFinancialMiniStat(
                      'Budget',
                      '₹${NumberFormat('#,##,###').format(budget)}',
                      Colors.blue.shade300,
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

  Widget _buildFinancialMiniStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContractWorkSection() {
    return _buildSectionCard(
      title: 'Contract Work',
      subtitle: 'Details if this project involves an external contractor',
      icon: Icons.handyman_rounded,
      trailing: Switch(
        value: _isContractWork,
        onChanged: (v) => setState(() => _isContractWork = v),
        activeColor: Theme.of(context).primaryColor,
      ),
      children: [
        if (!_isContractWork)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Enable to add contractor details',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ),
          ),
        if (_isContractWork) ...[
          _buildDropdownField(
            'Contractor Name',
            _contractorNameController.text.isEmpty
                ? null
                : _contractorNameController.text,
            _contractors,
            (v) => setState(() => _contractorNameController.text = v ?? ''),
            isLoading: _isLoadingDropdowns,
          ),
          const SizedBox(height: 16),
          GlassTextField(
            controller: _contractorBudgetController,
            label: 'Contractor Budget (₹)',
            icon: Icons.money_rounded,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          _buildDateField(
            'Contract Start',
            _contractStartDate,
            (d) => setState(() => _contractStartDate = d),
          ),
          const SizedBox(height: 16),
          _buildDateField(
            'Contract End',
            _contractEndDate,
            (d) => setState(() => _contractEndDate = d),
          ),
        ],
      ],
    );
  }

  // -------------------- STEP 3: SUPERVISOR ASSIGNMENT --------------------
  Widget _buildMapStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Form(
        key: _mapFormKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          children: [
            _buildStepHeader(
              'Supervisor Assignment',
              'Assign a supervisor to manage this project on-site',
            ),
            const SizedBox(height: 24),
            _buildSectionCard(
              title: 'Supervisor Selection',
              subtitle: 'Choose from registered supervisors',
              icon: Icons.people_rounded,
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
                      .map((s) => '${s['id']} - ${s['name']}')
                      .toList(),
                  isLoading: _isLoadingDropdowns,
                  validator: (v) =>
                      v == null ? 'Please select a supervisor' : null,
                ),
              ],
            ),
            _buildSectionCard(
              title: 'Assignment Details',
              subtitle: 'Set initial stage and joined date',
              icon: Icons.assignment_rounded,
              children: [
                _buildDropdownField(
                  'Project Stage',
                  _mapProjectStage,
                  _projectStagesList,
                  (v) => setState(() => _mapProjectStage = v),
                  isLoading: _isLoadingDropdowns,
                ),
                const SizedBox(height: 16),
                _buildDateField(
                  'Joined Date',
                  _joinedDate,
                  (d) => setState(() => _joinedDate = d),
                ),
                const SizedBox(height: 16),
                GlassTextField(
                  controller: _commentsController,
                  label: 'Site Comments (Optional)',
                  icon: Icons.comment_rounded,
                  maxLines: 3,
                ),
              ],
            ),
            _buildSummaryCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green.shade900.withOpacity(0.2),
            Colors.green.shade800.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.green.shade700.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.fact_check_rounded,
                    color: Colors.green.shade300,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Project Readiness',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade300,
                        ),
                      ),
                      Text(
                        'Review your configuration before saving',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade100.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildSummaryRow('Site Name', _siteNameController.text),
                _buildSummaryRow('Project', _projectNameController.text),
                _buildSummaryRow('Owner', _ownerNameController.text),
                _buildSummaryRow('Supervisor', _selectedSupervisorName),
                _buildSummaryRow('Stage', _projectStage),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: _isTermsAgreed,
                    onChanged: (v) =>
                        setState(() => _isTermsAgreed = v ?? false),
                    activeColor: Colors.green.shade400,
                    checkColor: Colors.black,
                    side: const BorderSide(color: Colors.white70, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _isTermsAgreed = !_isTermsAgreed),
                    child: Text(
                      'I have reviewed and agree to the project configuration and terms and conditions.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
          Text(
            (value == null || value.isEmpty) ? 'Not set' : value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // -------------------- REUSABLE UI COMPONENTS --------------------
  Widget _buildStepHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    String? subtitle,
    required IconData icon,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: Theme.of(context).primaryColor,
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(
    String label,
    DateTime? date,
    Function(DateTime) onSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
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
                    colorScheme: ColorScheme.dark(
                      primary: Theme.of(context).primaryColor,
                      onPrimary: Colors.white,
                      surface: Colors.grey.shade800,
                      onSurface: Colors.white,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) onSelected(picked);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    date == null
                        ? 'Select date'
                        : DateFormat('dd MMM yyyy').format(date),
                    style: TextStyle(
                      color: date == null ? Colors.grey.shade600 : Colors.black,
                      fontWeight: date != null ? FontWeight.w500 : null,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: Colors.black,
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
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : DropdownButton<String>(
                    value: value,
                    isExpanded: true,
                    style: const TextStyle(color: Colors.black, fontSize: 14),
                    iconEnabledColor: Colors.black,
                    hint: Text(
                      'Select $label',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    items: List.generate(
                      items.length,
                      (i) => DropdownMenuItem(
                        value: items[i],
                        child: Text(
                          displayItems != null ? displayItems[i] : items[i],
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    onChanged: onChanged,
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
          ),
        ),
      ],
    );
  }
}
