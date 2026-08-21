import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';

class WorkerMappingPage extends StatefulWidget {
  const WorkerMappingPage({super.key});

  @override
  State<WorkerMappingPage> createState() => _WorkerMappingPageState();
}

class _WorkerMappingPageState extends State<WorkerMappingPage> {
  // Selected values
  String? _selectedSite;
  String? _selectedSupervisor;
  String? _selectedProjectName;

  // Selected worker for current selection
  String? _selectedWorkerId;
  String? _selectedWorkerName;
  String? _selectedWorkerDesignation;
  String? _selectedWorkerSalary;
  String? _selectedWorkerPhone;

  // List of selected workers for the site
  List<Map<String, dynamic>> _selectedWorkersList = [];

  // Lists for dropdowns
  List<Map<String, dynamic>> _sites = [];
  List<Map<String, dynamic>> _workers = [];

  // Loading states
  bool _isLoadingSites = false;
  bool _isLoadingWorkers = false;
  bool _isSubmitting = false;

  Color get primaryColor => Theme.of(context).primaryColor;

  @override
  void initState() {
    super.initState();
    _loadSites();
    _loadWorkers();
  }

  Future<void> _loadSites() async {
    setState(() => _isLoadingSites = true);

    try {
      final siteSnapshot = await FirestoreService.getCollection('Site').get();
      if (!mounted) return;

      setState(() {
        _sites = siteSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'site': doc.id,
            'siteName': data['siteName'] ?? doc.id,
          };
        }).toList();
        _isLoadingSites = false;
      });
    } catch (e) {
      debugPrint('Error loading sites: $e');
      if (mounted) {
        setState(() => _isLoadingSites = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading sites: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _loadWorkers() async {
    setState(() => _isLoadingWorkers = true);

    try {
      final querySnapshot = await FirestoreService.getCollection(
        'workersConfig',
      ).limit(200).get();
      if (!mounted) return;
      setState(() {
        _workers = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? '',
            'designation': data['designation'] ?? '',
            'salary': data['salary'] ?? '',
            'phoneNumber': data['phoneNumber'] ?? '',
          };
        }).toList();
        _isLoadingWorkers = false;
      });
    } catch (e) {
      debugPrint('Error loading workers: $e');
      if (mounted) {
        setState(() => _isLoadingWorkers = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading workers: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _onSiteSelected(String? site) {
    setState(() {
      _selectedSite = site;
      _selectedSupervisor = null;
      _selectedProjectName = null;
      _selectedWorkersList.clear();
    });

    if (site != null) {
      _loadSiteDetails(site);
      _loadExistingWorkersForSite(site);
    }
  }

  Future<void> _loadSiteDetails(String siteId) async {
    try {
      final mapSnapshot = await FirestoreService.getCollection(
        'siteSupervisorMap',
      ).where('site', isEqualTo: siteId).limit(1).get();

      if (!mounted) return;

      if (mapSnapshot.docs.isNotEmpty) {
        final data = mapSnapshot.docs.first.data();
        setState(() {
          _selectedSupervisor = data['supervisor'] ?? 'Not available';
          _selectedProjectName = data['projectName'] ?? 'Not available';
        });
      } else {
        final siteDoc = await FirestoreService.getCollection(
          'Site',
        ).doc(siteId).get();
        if (!mounted) return;
        setState(() {
          _selectedSupervisor = 'Not available';
          if (siteDoc.exists) {
            final data = siteDoc.data()!;
            _selectedProjectName = data['siteName'] ?? 'Not available';
          } else {
            _selectedProjectName = 'Not available';
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching site details: $e');
    }
  }

  Future<void> _loadExistingWorkersForSite(String siteId) async {
    try {
      final existingDoc = await FirestoreService.getCollection(
        'workerSiteMapping',
      ).doc(siteId).get();

      if (!mounted) return;

      if (existingDoc.exists) {
        final data = existingDoc.data()!;
        final workersList = data['workers'] as List<dynamic>? ?? [];

        setState(() {
          _selectedWorkersList = workersList.map((w) {
            final workerMap = Map<String, dynamic>.from(w as Map);
            return {
              'workerId': workerMap['workerId'] ?? '',
              'workerName': workerMap['workerName'] ?? '',
              'workerDesignation': workerMap['workerDesignation'] ?? '',
              'workerSalary': workerMap['workerSalary'] ?? '',
              'workerPhone': workerMap['workerPhone'] ?? '',
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading existing workers mapping: $e');
    }
  }

  void _onWorkerSelected(String? workerId) {
    if (workerId == null) {
      setState(() {
        _selectedWorkerId = null;
        _selectedWorkerName = null;
        _selectedWorkerDesignation = null;
        _selectedWorkerSalary = null;
        _selectedWorkerPhone = null;
      });
      return;
    }

    final worker = _workers.firstWhere(
      (w) => w['id'] == workerId,
      orElse: () => {},
    );

    if (worker.isNotEmpty) {
      setState(() {
        _selectedWorkerId = workerId;
        _selectedWorkerName = worker['name'];
        _selectedWorkerDesignation = worker['designation'];
        _selectedWorkerSalary = worker['salary'];
        _selectedWorkerPhone = worker['phoneNumber'];
      });
    }
  }

  void _addWorkerToList() {
    if (_selectedWorkerId == null || _selectedWorkerName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a worker profile'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final isAlreadyAdded = _selectedWorkersList.any(
      (w) => w['workerId'] == _selectedWorkerId || w['workerName'] == _selectedWorkerName,
    );

    if (isAlreadyAdded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Worker "$_selectedWorkerName" is already in the list'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    setState(() {
      _selectedWorkersList.add({
        'workerId': _selectedWorkerId,
        'workerName': _selectedWorkerName,
        'workerDesignation': _selectedWorkerDesignation ?? '',
        'workerSalary': _selectedWorkerSalary ?? '',
        'workerPhone': _selectedWorkerPhone ?? '',
      });

      _selectedWorkerId = null;
      _selectedWorkerName = null;
      _selectedWorkerDesignation = null;
      _selectedWorkerSalary = null;
      _selectedWorkerPhone = null;
    });
  }

  void _removeWorkerFromList(int index) {
    setState(() {
      _selectedWorkersList.removeAt(index);
    });
  }

  bool get _isFormComplete {
    return _selectedSite != null &&
        _selectedSite!.isNotEmpty &&
        _selectedWorkersList.isNotEmpty;
  }

  Future<void> _submitMapping() async {
    if (!_isFormComplete) return;

    setState(() => _isSubmitting = true);

    try {
      final docData = {
        'site': _selectedSite,
        'supervisor': _selectedSupervisor ?? 'Not available',
        'projectName': _selectedProjectName ?? 'Not available',
        'totalWorkersMapped': _selectedWorkersList.length,
        'workers': _selectedWorkersList,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirestoreService.getCollection('workerSiteMapping')
          .doc(_selectedSite)
          .set(docData, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Successfully mapped ${_selectedWorkersList.length} workers to site $_selectedSite!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving worker mapping: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final primaryColor = Theme.of(context).primaryColor;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Worker Site Mapping',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                darkAccent,
                Color.alphaBlend(
                  primaryColor.withValues(alpha: 0.35),
                  darkAccent,
                ),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 650,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionCard(
                    title: 'Select Site & Project',
                    icon: Icons.location_city_rounded,
                    primaryColor: primaryColor,
                    children: [
                      _buildSiteDropdown(primaryColor),
                      if (_selectedSupervisor != null ||
                          _selectedProjectName != null) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDetailTile(
                                Icons.person_rounded,
                                'Supervisor',
                                _selectedSupervisor ?? 'Not available',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildDetailTile(
                                Icons.business_center_rounded,
                                'Project Name',
                                _selectedProjectName ?? 'Not available',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),

                  _buildSectionCard(
                    title: 'Select Worker to Add',
                    icon: Icons.person_add_alt_1_rounded,
                    primaryColor: primaryColor,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: _buildWorkerDropdown(primaryColor),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _addWorkerToList,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 20),
                              label: const Text(
                                'ADD',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_selectedWorkerDesignation != null ||
                          _selectedWorkerSalary != null) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDetailTile(
                                Icons.construction_rounded,
                                'Role',
                                _selectedWorkerDesignation ?? 'N/A',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildDetailTile(
                                Icons.payments_rounded,
                                'Daily Wage',
                                '₹${_selectedWorkerSalary ?? '0'}',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),

                  if (_selectedWorkersList.isNotEmpty)
                    _buildSelectedWorkersCard(primaryColor),

                  const SizedBox(height: 16),

                  _buildSubmitButton(primaryColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color primaryColor,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.04),
            blurRadius: 10,
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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: primaryColor),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0A183D),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSiteDropdown(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Site *',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _selectedSite,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(14),
            decoration: InputDecoration(
              hintText: 'Choose site location',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              prefixIcon: Icon(
                Icons.location_on_rounded,
                color: primaryColor,
                size: 20,
              ),
            ),
            style: const TextStyle(
              color: Color(0xFF0A183D),
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
            items: _isLoadingSites
                ? [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Loading sites...'),
                    ),
                  ]
                : _sites.map<DropdownMenuItem<String>>((site) {
                    final displayName = site['siteName'] != site['site']
                        ? '${site['site']} (${site['siteName']})'
                        : site['site'] ?? '';
                    return DropdownMenuItem<String>(
                      value: site['site'] as String?,
                      child: Text(
                        displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
            onChanged: _onSiteSelected,
          ),
        ),
      ],
    );
  }

  Widget _buildWorkerDropdown(Color primaryColor) {
    final availableWorkers = _workers.where((worker) {
      return !_selectedWorkersList.any(
        (selectedWorker) => selectedWorker['workerName'] == worker['name'],
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Worker Profile *',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _selectedWorkerId,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(14),
            decoration: InputDecoration(
              hintText: 'Choose registered worker',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              prefixIcon: Icon(
                Icons.badge_rounded,
                color: primaryColor,
                size: 20,
              ),
            ),
            style: const TextStyle(
              color: Color(0xFF0A183D),
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
            items: _isLoadingWorkers
                ? [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Loading workers...'),
                    ),
                  ]
                : availableWorkers.map<DropdownMenuItem<String>>((worker) {
                    final String name = worker['name']?.toString().trim() ?? '';
                    final String des = worker['designation']?.toString().trim() ?? '';
                    final String displayName = name.isNotEmpty
                        ? (des.isNotEmpty ? '$name ($des)' : name)
                        : 'Unnamed (${worker['id']})';
                    return DropdownMenuItem<String>(
                      value: worker['id'] as String?,
                      child: Text(
                        displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
            onChanged: _onWorkerSelected,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A183D),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedWorkersCard(Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.groups_rounded,
                      size: 18,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Mapped Workers (${_selectedWorkersList.length})',
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0A183D),
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedWorkersList.clear();
                  });
                },
                icon: const Icon(Icons.clear_all_rounded, size: 16),
                label: const Text('Clear All'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectedWorkersList.length,
            separatorBuilder: (context, index) =>
                const Divider(color: Color(0xFFE2E8F0), height: 12),
            itemBuilder: (context, index) {
              final worker = _selectedWorkersList[index];
              return Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          worker['workerName'] ?? 'Unnamed',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0A183D),
                          ),
                        ),
                        Row(
                          children: [
                            if (worker['workerDesignation'] != null) ...[
                              Text(
                                worker['workerDesignation'] ?? '',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const Text(' • ', style: TextStyle(color: Color(0xFF94A3B8))),
                            ],
                            Text(
                              '₹${worker['workerSalary'] ?? '0'}/day',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline_rounded,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                    onPressed: () => _removeWorkerFromList(index),
                    tooltip: 'Remove',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(Color primaryColor) {
    return Column(
      children: [
        if (!_isFormComplete && _selectedSite != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    _selectedWorkersList.isEmpty
                        ? 'Add at least one worker to save site mapping'
                        : 'Waiting for site details...',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        _isSubmitting
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isFormComplete ? _submitMapping : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    disabledForegroundColor: Colors.grey[500],
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
                  label: const Text(
                    'SAVE WORKER SITE MAPPING',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
      ],
    );
  }
}
