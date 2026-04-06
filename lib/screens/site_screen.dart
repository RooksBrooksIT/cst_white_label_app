import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lottie/lottie.dart';
import '../services/firestore_service.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_text_field.dart';
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
  String? _projectType;
  String _status = 'In-Progress';
  bool _isGettingLocation = false;
  bool _isSaving = false;
  bool isUpdateMode = false;
  String? selectedSiteId;

  final Color purple = const Color(0xFF9C27B0);
  final Color bgColor = const Color(0xFFF1F5F9);
  final Color borderColor = const Color.fromARGB(255, 169, 172, 175);
  final Color textColor = const Color(0xFF64748B);
  final Color scaffoldBg = const Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _initializeDefaults();
  }

  Future<void> _loadSiteData(String siteDocId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Site')
          .doc(siteDocId)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _siteNameController.text = data['siteName'] ?? '';
          _locationController.text = data['location'] ?? '';
          _latitudeController.text = (data['latitude'] ?? '').toString();
          _longitudeController.text = (data['longitude'] ?? '').toString();
          _projectType = data['projectType'];
          _status = data['status'] ?? 'In-Progress';
          _startDate = data['startDate'] != null && data['startDate'] != ''
              ? (data['startDate'] is Timestamp
                    ? (data['startDate'] as Timestamp).toDate()
                    : DateFormat('yyyy-MM-dd').parse(data['startDate']))
              : null;
          _endDate = data['endDate'] != null && data['endDate'] != ''
              ? (data['endDate'] is Timestamp
                    ? (data['endDate'] as Timestamp).toDate()
                    : DateFormat('yyyy-MM-dd').parse(data['endDate']))
              : null;
        });
      }
    } catch (e) {
      debugPrint('Error loading site data: $e');
    }
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
      final snapshot = await FirebaseFirestore.instance
          .collection('projectCategories')
          .get();
      final categories = snapshot.docs
          .map((doc) => doc['projectCategory']?.toString().trim())
          .where((val) => val != null && val.isNotEmpty)
          .cast<String>()
          .toList();
      return categories;
    } catch (e) {
      throw 'Failed to load categories: $e';
    }
  }

  Future<List<String>> fetchProjectStatus() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projectStatus')
          .get();
      final statusList = snapshot.docs
          .map((doc) => doc['projectState']?.toString().trim())
          .where((val) => val != null && val.isNotEmpty)
          .cast<String>()
          .toList();
      return statusList;
    } catch (e) {
      throw 'Failed to load status options: $e';
    }
  }

  // Internal date selection logic removed/replaced by inline pickers in _buildModernDatePicker

  Future<String> _getNextSiteId(String siteName) async {
    final snapshot = await FirebaseFirestore.instance.collection('Site').get();
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
    if (!mounted) return;
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
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String address = [
          place.street,
          place.locality,
          place.administrativeArea,
          place.country,
        ].where((part) => part?.isNotEmpty ?? false).join(', ');
        setState(() {
          _latitudeController.text = position.latitude.toStringAsFixed(6);
          _longitudeController.text = position.longitude.toStringAsFixed(6);
          _locationController.text = address;
        });
      }
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
    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          decoration: BoxDecoration(
            color: purple,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(30),
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text(
                    "Site Details",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildWhiteCard(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildToggleButton(
                        label: 'New Site',
                        isActive: !isUpdateMode,
                        onTap: () => setState(() {
                          isUpdateMode = false;
                          _resetForm();
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildToggleButton(
                        label: 'Update Site',
                        isActive: isUpdateMode,
                        onTap: () => setState(() {
                          isUpdateMode = true;
                          _resetForm();
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (isUpdateMode)
                _buildWhiteCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Site',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: purple,
                        ),
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('Site')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData)
                            return const Center(
                              child: CircularProgressIndicator(),
                            );

                          final docs = snapshot.data!.docs;
                          final items = docs.map((d) {
                            final data = d.data() as Map<String, dynamic>;
                            return "${data['siteName'] ?? ''} (${data['siteId'] ?? ''})";
                          }).toList();

                          if (items.isEmpty) {
                            return const Text(
                              'No sites found',
                              style: TextStyle(color: Colors.red),
                            );
                          }

                          String? dropdownValue;
                          if (selectedSiteId != null) {
                            try {
                              final doc = docs.firstWhere(
                                (d) => d.id == selectedSiteId,
                              );
                              final data = doc.data() as Map<String, dynamic>;
                              dropdownValue =
                                  "${data['siteName'] ?? ''} (${data['siteId'] ?? ''})";
                            } catch (e) {}
                          }

                          return _buildModernDropdown(
                            label: 'Site to Update',
                            value: items.contains(dropdownValue)
                                ? dropdownValue
                                : null,
                            items: items,
                            icon: Icons.location_on_outlined,
                            onChanged: (val) {
                              final doc = docs.firstWhere((d) {
                                final data = d.data() as Map<String, dynamic>;
                                return "${data['siteName'] ?? ''} (${data['siteId'] ?? ''})" ==
                                    val;
                              });
                              _loadSiteData(doc.id);
                              setState(() => selectedSiteId = doc.id);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              if (isUpdateMode) const SizedBox(height: 20),
              _buildWhiteCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Site Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: purple,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildModernTextField(
                      controller: _siteNameController,
                      label: 'Site Name',
                      icon: Icons.business,
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildModernTextField(
                            controller: _locationController,
                            label: 'Location',
                            icon: Icons.map_outlined,
                            validator: (v) =>
                                v?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(top: 25),
                          child: Container(
                            decoration: BoxDecoration(
                              color: purple,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: _isGettingLocation
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.gps_fixed,
                                      color: Colors.white,
                                    ),
                              onPressed: _isGettingLocation
                                  ? null
                                  : _getCurrentLocation,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildModernTextField(
                            controller: _latitudeController,
                            label: 'Latitude',
                            icon: Icons.north_outlined,
                            readOnly: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildModernTextField(
                            controller: _longitudeController,
                            label: 'Longitude',
                            icon: Icons.east_outlined,
                            readOnly: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildWhiteCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Project Lifecycle',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: purple,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildModernDropdown(
                      label: 'Project Type',
                      items: [], // Will be populated by FutureBuilder below
                      value: _projectType,
                      icon: Icons.category_outlined,
                      onChanged: (v) => setState(() => _projectType = v),
                      futureItems: fetchProjectCategories(),
                    ),
                    const SizedBox(height: 16),
                    _buildModernDropdown(
                      label: 'Status',
                      items: [], // Will be populated by FutureBuilder below
                      value: _status,
                      icon: Icons.info_outline,
                      onChanged: (v) =>
                          setState(() => _status = v ?? 'In-Progress'),
                      futureItems: fetchProjectStatus(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildModernDatePicker(
                            label: 'Start Date',
                            date: _startDate,
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _startDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null)
                                setState(() => _startDate = picked);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildModernDatePicker(
                            label: 'End Date',
                            date: _endDate,
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _endDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null)
                                setState(() => _endDate = picked);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: purple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSaving ? null : _saveSiteDetails,
                  child: Text(
                    _isSaving
                        ? 'Saving...'
                        : (isUpdateMode ? 'Update Site' : 'Save Site'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWhiteCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? purple : bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          validator: validator,
          style: const TextStyle(color: Colors.black87, fontSize: 16),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: textColor),
            fillColor: bgColor,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: purple, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required IconData icon,
    required Function(String?) onChanged,
    Future<List<String>>? futureItems,
  }) {
    if (futureItems != null) {
      return FutureBuilder<List<String>>(
        future: futureItems,
        builder: (context, snapshot) {
          final list = snapshot.data ?? items;
          return _buildDropdownInternal(label, value, list, icon, onChanged);
        },
      );
    }
    return _buildDropdownInternal(label, value, items, icon, onChanged);
  }

  Widget _buildDropdownInternal(
    String label,
    String? value,
    List<String> items,
    IconData icon,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: items.contains(value) ? value : null,
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(
                    e,
                    style: const TextStyle(color: Colors.black87, fontSize: 15),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          dropdownColor: Colors.white,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: textColor),
            fillColor: bgColor,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: purple, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernDatePicker({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date == null
                      ? "Select"
                      : DateFormat('yyyy-MM-dd').format(date),
                  style: TextStyle(
                    color: date == null ? Colors.grey : Colors.black87,
                  ),
                ),
                Icon(Icons.calendar_today, color: textColor, size: 20),
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
    final projectType = _projectType ?? '';
    final status = _status.isNotEmpty ? _status : 'In-Progress';

    try {
      if (!isUpdateMode) {
        // Deduplication
        final dupQuery = await FirebaseFirestore.instance
            .collection('Site')
            .where('siteName', isEqualTo: siteName)
            .where('location', isEqualTo: location)
            .limit(1)
            .get();
        if (dupQuery.docs.isNotEmpty) {
          if (mounted) setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Duplicate site detected.')),
          );
          return;
        }

        final nextId = await _getNextSiteId(siteName);
        final siteDocId = nextId + '_' + siteName.replaceAll(' ', '');

        final siteData = {
          'siteId': nextId,
          'siteName': siteName,
          'location': location,
          'latitude': latitude.isNotEmpty ? double.tryParse(latitude) : null,
          'longitude': longitude.isNotEmpty ? double.tryParse(longitude) : null,
          'projectType': projectType,
          'startDate': startDate,
          'endDate': endDate,
          'status': status,
          'createdAt': FieldValue.serverTimestamp(),
        };

        await FirebaseFirestore.instance
            .collection('Site')
            .doc(siteDocId)
            .set(siteData);

        // Auto Create Project
        final projectsSnapshot = await FirebaseFirestore.instance
            .collection('projects')
            .get();
        int maxPRNum = 0;
        for (final doc in projectsSnapshot.docs) {
          if (doc.id.startsWith('PR')) {
            final numeric = int.tryParse(doc.id.substring(2));
            if (numeric != null && numeric > maxPRNum) maxPRNum = numeric;
          }
        }
        final nextPrId = 'PR${(maxPRNum + 1).toString().padLeft(3, '0')}';

        await FirebaseFirestore.instance
            .collection('projects')
            .doc(nextPrId)
            .set({
              'createdAt': FieldValue.serverTimestamp(),
              'siteId': siteDocId,
              'siteName': siteName,
              'plannedStartDate': _startDate != null
                  ? Timestamp.fromDate(_startDate!)
                  : null,
              'plannedEndDate': _endDate != null
                  ? Timestamp.fromDate(_endDate!)
                  : null,
              'projectType': projectType,
              'status': status,
              'ownerName': '',
              'projectName': siteName,
              'amountPaid': 0.0,
              'projectBudget': 0.0,
              'amountSpent': 0.0,
              'amountBalance': 0.0,
            });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Site and Project created successfully!'),
          ),
        );

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ProjectScreen(projectId: nextPrId),
            ),
          );
        }
      } else if (selectedSiteId != null) {
        await FirebaseFirestore.instance
            .collection('Site')
            .doc(selectedSiteId)
            .update({
              'siteName': siteName,
              'location': location,
              'projectType': projectType,
              'startDate': startDate,
              'endDate': endDate,
              'status': status,
              'updatedAt': FieldValue.serverTimestamp(),
            });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Site updated successfully!')),
        );
        _resetForm();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSuccessDialog(String siteId, String projectId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 6,
          child: Padding(
            padding: const EdgeInsets.all(26.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/animation/success.json',
                  width: 110,
                  height: 110,
                  repeat: false,
                ),
                const SizedBox(height: 20),
                Text(
                  'Success!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: purple,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Project created with ID $siteId.\nPlease update the project details.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, color: Colors.black87),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: purple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    elevation: 5,
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
                    'OK',
                    style: TextStyle(color: Colors.white, fontSize: 16),
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
      _startDate = null;
      _endDate = null;
      _projectType = null;
      _status = 'In-Progress';
    });
  }

  @override
  void dispose() {
    _siteNameController.dispose();
    _locationController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }
}
