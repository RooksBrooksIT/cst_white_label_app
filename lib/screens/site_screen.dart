import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_text_field.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

class SiteScreen extends StatefulWidget {
  const SiteScreen({super.key});

  @override
  State<SiteScreen> createState() => _SiteScreenState();
}

class _SiteScreenState extends State<SiteScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _siteNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  String? _projectType;
  String _status = 'In Progress';
  bool _isGettingLocation = false;
  bool _isSaving = false;

  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeDefaults();
  }

  @override
  void dispose() {
    _siteNameController.dispose();
    _locationController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _initializeDefaults() async {
    final statusList = await fetchProjectStatus();
    if (statusList.isNotEmpty && mounted) {
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
      return snapshot.docs
          .map((doc) => doc['projectCategory']?.toString().trim() ?? '')
          .where((val) => val.isNotEmpty)
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<String>> fetchProjectStatus() async {
    // Default statuses as requested by the user
    final defaultStatuses = ['In Progress', 'On Hold', 'Completed'];
    try {
      final snapshot = await FirestoreService.getCollection(
        'projectStatus',
      ).get();
      final dbStatuses = snapshot.docs
          .map((doc) => doc['projectState']?.toString().trim() ?? '')
          .where((val) => val.isNotEmpty)
          .toList();

      // Merge defaults with database values and remove duplicates
      return {...defaultStatuses, ...dbStatuses}.toList();
    } catch (e) {
      return defaultStatuses;
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final theme = Theme.of(context);
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
            colorScheme: ColorScheme.light(
              primary: theme.primaryColor,
              onPrimary: Colors.white,
              onSurface: theme.colorScheme.onSurface,
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
          if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    setState(() => _isGettingLocation = true);
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassScaffold(
      title: 'Site Details',
      bottom: TabBar(
        controller: _tabController,
        labelColor: theme.cardColor,
        unselectedLabelColor: theme.cardColor.withOpacity(0.7),
        indicatorColor: theme.cardColor,
        indicatorWeight: 3,
        tabs: const [
          Tab(text: 'NEW SITE'),
          Tab(text: 'ALL SITES'),
        ],
      ),
      padding: EdgeInsets.zero, // Use full width for TabBarView
      body: TabBarView(
        controller: _tabController,
        children: [_buildNewSiteTab(), _buildAllSiteTab()],
      ),
    );
  }

  Widget _buildNewSiteTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Site Information',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassTextField(
                    controller: _siteNameController,
                    label: 'Site Name',
                    icon: Icons.location_on_outlined,
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GlassTextField(
                          controller: _locationController,
                          label: 'Location',
                          icon: Icons.map_outlined,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: _isGettingLocation
                            ? null
                            : _getCurrentLocation,
                        icon: _isGettingLocation
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GlassTextField(
                          controller: _latitudeController,
                          label: 'Latitude',
                          icon: Icons.explore_outlined,
                          readOnly: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GlassTextField(
                          controller: _longitudeController,
                          label: 'Longitude',
                          icon: Icons.explore_outlined,
                          readOnly: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Project Details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<List<String>>(
                    future: fetchProjectCategories(),
                    builder: (context, snapshot) {
                      final items = snapshot.data ?? [];
                      return _buildDropdownField(
                        value:
                            _projectType ??
                            (items.isNotEmpty ? items.first : null),
                        label: 'Project Category',
                        items: items,
                        icon: Icons.category_outlined,
                        onChanged: (v) => setState(() => _projectType = v),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildDatePicker(
                    'Start Date',
                    _startDate,
                    () => _selectDate(context, true),
                  ),
                  const SizedBox(height: 12),
                  _buildDatePicker(
                    'End Date',
                    _endDate,
                    () => _selectDate(context, false),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<String>>(
                    future: fetchProjectStatus(),
                    builder: (context, snapshot) {
                      final items = snapshot.data ?? [];
                      return _buildDropdownField(
                        value: _status,
                        label: 'Project Status',
                        items: items,
                        icon: Icons.timeline_outlined,
                        onChanged: (v) => setState(() => _status = v!),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GlassButton(
                    label: 'SAVE SITE',
                    onPressed: _isSaving ? null : _saveSiteDetails,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassButton(
                    label: 'RESET',
                    onPressed: _resetForm,
                    isSecondary: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllSiteTab() {
    final theme = Theme.of(context);
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.getCollection('Site').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final sites = snapshot.data!.docs;
        if (sites.isEmpty) return const Center(child: Text('No sites found.'));

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: sites.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final data = sites[index].data() as Map<String, dynamic>;
            return GlassCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  data['siteName'] ?? 'Unnamed Site',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(data['location'] ?? 'No location'),
                trailing: Text(
                  data['siteId'] ?? '',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.primaryColor,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String label,
    required List<String> items,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    final theme = Theme.of(context);
    return DropdownButtonFormField<String>(
      value: (value != null && items.contains(value)) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: theme.cardColor,
      ),
      items: items
          .toSet()
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDatePicker(String label, DateTime? date, VoidCallback onTap) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: theme.cardColor,
        ),
        child: Text(
          date == null ? 'Select Date' : DateFormat('dd MMM yyyy').format(date),
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }

  void _resetForm() {
    if (!mounted) return;
    _siteNameController.clear();
    _locationController.clear();
    _latitudeController.clear();
    _longitudeController.clear();
    setState(() {
      _startDate = null;
      _endDate = null;
      _projectType = null;
    });
  }

  Future<void> _saveSiteDetails() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    if (mounted) setState(() => _isSaving = true);

    try {
      final siteId =
          'ST${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final data = {
        'siteId': siteId,
        'siteName': _siteNameController.text.trim(),
        'location': _locationController.text.trim(),
        'latitude': double.tryParse(_latitudeController.text),
        'longitude': double.tryParse(_longitudeController.text),
        'projectType': _projectType,
        'startDate': _startDate != null
            ? DateFormat('yyyy-MM-dd').format(_startDate!)
            : null,
        'endDate': _endDate != null
            ? DateFormat('yyyy-MM-dd').format(_endDate!)
            : null,
        'status': _status,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirestoreService.getCollection('Site').doc(siteId).set(data);
      _resetForm();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Site saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
