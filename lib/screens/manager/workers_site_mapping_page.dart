import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';

class WorkerMappingPage extends StatefulWidget {
  const WorkerMappingPage({super.key});

  @override
  _WorkerMappingPageState createState() => _WorkerMappingPageState();
}

class _WorkerMappingPageState extends State<WorkerMappingPage> {
  // Removed _firestore field
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

  @override
  void initState() {
    super.initState();
    _loadSites();
    _loadWorkers();
  }

  Future<void> _loadSites() async {
    setState(() {
      _isLoadingSites = true;
    });

    try {
      // Fetch sites from the 'Site' collection (doc.id = site identifier)
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
        setState(() {
          _isLoadingSites = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading sites: $e')));
      }
    }
  }

  Future<void> _loadWorkers() async {
    setState(() {
      _isLoadingWorkers = true;
    });

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
        setState(() {
          _isLoadingWorkers = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading workers: $e')));
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
      // Look up supervisor and project info from siteSupervisorMap
      _loadSiteDetails(site);
      // Load existing workers for this site if any
      _loadExistingWorkersForSite(site);
    }
  }

  Future<void> _loadSiteDetails(String siteId) async {
    try {
      // Query siteSupervisorMap for this site's supervisor and project name
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
        // Fallback: try to get project name from Site collection
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
      debugPrint('Error loading site details: $e');
      if (mounted) {
        setState(() {
          _selectedSupervisor = 'Error loading';
          _selectedProjectName = 'Error loading';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading site details: $e')),
        );
      }
    }
  }

  Future<void> _loadExistingWorkersForSite(String site) async {
    try {
      final doc = await FirestoreService.getCollection(
        'workerSiteMap',
      ).doc(site).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final existingWorkers = List<Map<String, dynamic>>.from(
          data['workers'] ?? [],
        );

        if (mounted) {
          setState(() {
            _selectedWorkersList = existingWorkers;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Loaded ${existingWorkers.length} existing workers for this site',
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading existing workers: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading existing workers: $e')),
        );
      }
    }
  }

  void _onWorkerSelected(String? workerId) {
    setState(() {
      _selectedWorkerId = workerId;
      _selectedWorkerName = null;
      _selectedWorkerDesignation = null;
      _selectedWorkerSalary = null;
      _selectedWorkerPhone = null;
    });

    if (workerId != null) {
      // Find the selected worker details
      final selectedWorkerData = _workers.firstWhere(
        (worker) => worker['id'] == workerId,
        orElse: () => {},
      );

      if (selectedWorkerData.isNotEmpty) {
        setState(() {
          _selectedWorkerName = selectedWorkerData['name'];
          _selectedWorkerDesignation = selectedWorkerData['designation'];
          _selectedWorkerSalary = selectedWorkerData['salary'];
          _selectedWorkerPhone = selectedWorkerData['phoneNumber'];
        });
      }
    }
  }

  void _addWorkerToList() {
    if (_selectedWorkerId == null || _selectedWorkerName == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please select a worker first')));
      return;
    }

    // Check if worker is already added in current session
    bool alreadyExists = _selectedWorkersList.any(
      (worker) => worker['workerName'] == _selectedWorkerName,
    );

    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Worker already added to the list')),
      );
      return;
    }

    setState(() {
      _selectedWorkersList.add({
        'workerId': _selectedWorkerId,
        'workerName': _selectedWorkerName,
        'workerDesignation': _selectedWorkerDesignation,
        'workerSalary': _selectedWorkerSalary,
        'workerPhone': _selectedWorkerPhone,
        'addedAt': DateTime.now().toIso8601String(),
      });
    });

    // Reset current selection
    setState(() {
      _selectedWorkerId = null;
      _selectedWorkerName = null;
      _selectedWorkerDesignation = null;
      _selectedWorkerSalary = null;
      _selectedWorkerPhone = null;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Worker added to list')));
  }

  void _removeWorkerFromList(int index) {
    setState(() {
      _selectedWorkersList.removeAt(index);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Worker removed from list')));
  }

  Future<void> _submitMapping() async {
    // Validation
    if (!_isFormComplete) {
      String missing = '';
      if (_selectedSite == null)
        missing = 'site selection';
      else if (_selectedSupervisor == null || _selectedProjectName == null)
        missing = 'site details (waiting for fetch)';
      else if (_selectedWorkersList.isEmpty)
        missing = 'at least one worker';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please complete the form: missing $missing')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Mapping'),
        content: Text(
          'Are you sure you want to save the worker mapping for $_selectedSite? This will update the existing records if any.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);

    try {
      // Use site name as document ID
      final docRef = FirestoreService.getCollection(
        'workerSiteMap',
      ).doc(_selectedSite!);

      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        // Document exists - update it
        final existingData = docSnapshot.data() as Map<String, dynamic>;
        final existingWorkers = List<Map<String, dynamic>>.from(
          existingData['workers'] ?? [],
        );

        // Remove duplicates and combine lists
        final allWorkers = _mergeWorkersWithoutDuplicates(
          existingWorkers,
          _selectedWorkersList,
        );

        await docRef.update({
          'workers': allWorkers,
          'totalWorkers': allWorkers.length,
          'updatedAt': FieldValue.serverTimestamp(),
          'supervisor': _selectedSupervisor,
          'projectName': _selectedProjectName,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Updated site mapping with ${allWorkers.length} workers',
            ),
          ),
        );
      } else {
        // Document doesn't exist - create it
        await docRef.set({
          'site': _selectedSite,
          'supervisor': _selectedSupervisor,
          'projectName': _selectedProjectName,
          'workers': _selectedWorkersList,
          'mappedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'status': 'active',
          'totalWorkers': _selectedWorkersList.length,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Created new site mapping with ${_selectedWorkersList.length} workers',
            ),
          ),
        );
      }

      // Reset form
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _selectedSite = null;
          _selectedSupervisor = null;
          _selectedProjectName = null;
          _selectedWorkersList.clear();
        });
      }
    } catch (e) {
      debugPrint('Error mapping workers: $e');
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error mapping workers: $e')));
      }
    }
  }

  List<Map<String, dynamic>> _mergeWorkersWithoutDuplicates(
    List<Map<String, dynamic>> existingWorkers,
    List<Map<String, dynamic>> newWorkers,
  ) {
    final Map<String, Map<String, dynamic>> workerMap = {};

    // Add existing workers to the map
    for (final worker in existingWorkers) {
      final workerName = worker['workerName']?.toString();
      if (workerName != null) {
        workerMap[workerName] = worker;
      }
    }

    // Add new workers to the map (this will overwrite duplicates with new data)
    for (final worker in newWorkers) {
      final workerName = worker['workerName']?.toString();
      if (workerName != null) {
        workerMap[workerName] = worker;
      }
    }

    return workerMap.values.toList();
  }

  bool get _isFormComplete {
    return _selectedSite != null &&
        _selectedSupervisor != null &&
        _selectedProjectName != null &&
        _selectedWorkersList.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 600;

    final colorScheme = Theme.of(context).colorScheme;

    return GlassScaffold(
      title: 'Worker Site Mapping',
      appBarForegroundColor: Colors.white,
      onBack: () => Navigator.pop(context),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Site Selection Section
              _buildSectionHeader('Select Site'),
              _buildSiteSelectionSection(),

              SizedBox(height: 24),

              // Worker Selection Section
              _buildSectionHeader('Select Workers'),
              _buildWorkerSelectionSection(),

              SizedBox(height: 16),

              // Selected Workers Table
              if (_selectedWorkersList.isNotEmpty) _buildWorkersTable(),

              SizedBox(height: 32),

              // Submit Button
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFF0A183D),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0A183D),
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteSelectionSection() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final darkCardBg = AppTheme.getDarkAccent(primaryColor);

    return Container(
      padding: const EdgeInsets.all(20),
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
          const Text(
            'Site',
            style: TextStyle(
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
              isExpanded: true,
              value: _selectedSite,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(16),
              decoration: InputDecoration(
                hintText: 'Select Site',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                prefixIcon: const Icon(
                  Icons.construction_rounded,
                  color: Color(0xFF0A183D),
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

          const SizedBox(height: 16),

          // Auto-filled Supervisor and Project Name
          if (_selectedSupervisor != null || _selectedProjectName != null)
            Column(
              children: [
                _buildReadOnlyField(
                  'Supervisor',
                  _selectedSupervisor ?? 'Not available',
                ),
                const SizedBox(height: 12),
                _buildReadOnlyField(
                  'Project Name',
                  _selectedProjectName ?? 'Not available',
                ),
              ],
            )
          else if (_selectedSite != null)
            const Text(
              'No supervisor/project details found for this site',
              style: TextStyle(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWorkerSelectionSection() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final darkCardBg = AppTheme.getDarkAccent(primaryColor);

    // Filter out workers that are already in the list
    final availableWorkers = _workers.where((worker) {
      return !_selectedWorkersList.any(
        (selectedWorker) => selectedWorker['workerName'] == worker['name'],
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
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
          const Text(
            'Select Worker',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Container(
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
                    isExpanded: true,
                    value: _selectedWorkerId,
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    decoration: InputDecoration(
                      hintText: 'Select Worker',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.person_rounded,
                        color: Color(0xFF0A183D),
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
                        : availableWorkers.map<DropdownMenuItem<String>>((
                            worker,
                          ) {
                            final String name =
                                worker['name']?.toString().trim() ?? '';
                            final String displayName = name.isNotEmpty
                                ? name
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
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 52,
                width: 56,
                child: FilledButton(
                  onPressed: _addWorkerToList,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Icon(Icons.add_rounded, size: 26),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Auto-filled Worker Details
          if (_selectedWorkerDesignation != null ||
              _selectedWorkerSalary != null)
            Column(
              children: [
                _buildReadOnlyField(
                  'Designation',
                  _selectedWorkerDesignation ?? 'Not available',
                ),
                const SizedBox(height: 12),
                _buildReadOnlyField(
                  'Salary',
                  _selectedWorkerSalary ?? 'Not available',
                ),
                const SizedBox(height: 12),
                if (_selectedWorkerPhone != null)
                  _buildReadOnlyField(
                    'Phone',
                    _selectedWorkerPhone ?? 'Not available',
                  ),
              ],
            )
          else if (_selectedWorkerId != null)
            const Text(
              'No details found for this worker',
              style: TextStyle(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWorkersTable() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final darkCardBg = AppTheme.getDarkAccent(primaryColor);

    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Selected Workers (${_selectedWorkersList.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              if (_selectedWorkersList.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedWorkersList.clear();
                    });
                  },
                  icon: const Icon(Icons.clear_all_rounded, size: 18),
                  label: const Text('Clear All'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFF87171),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  Colors.white.withValues(alpha: 0.1),
                ),
                headingTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
                columns: const [
                  DataColumn(label: Text('No.')),
                  DataColumn(label: Text('Worker Name')),
                  DataColumn(label: Text('Designation')),
                  DataColumn(label: Text('Salary')),
                  DataColumn(label: Text('Phone')),
                  DataColumn(label: Text('Action')),
                ],
                rows: _selectedWorkersList.asMap().entries.map((entry) {
                  final index = entry.key;
                  final worker = entry.value;
                  return DataRow(
                    cells: [
                      DataCell(Text(
                        '${index + 1}',
                        style: const TextStyle(color: Colors.white),
                      )),
                      DataCell(Text(
                        worker['workerName'] ?? '',
                        style: const TextStyle(color: Colors.white),
                      )),
                      DataCell(Text(
                        worker['workerDesignation'] ?? '',
                        style: const TextStyle(color: Colors.white),
                      )),
                      DataCell(Text(
                        worker['workerSalary'] ?? '',
                        style: const TextStyle(color: Colors.white),
                      )),
                      DataCell(Text(
                        worker['workerPhone'] ?? '',
                        style: const TextStyle(color: Colors.white),
                      )),
                      DataCell(
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFFF87171),
                            size: 20,
                          ),
                          onPressed: () => _removeWorkerFromList(index),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFFCBD5E1),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final darkCardBg = AppTheme.getDarkAccent(primaryColor);

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
                        ? 'Add at least one worker to save mapping'
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
        Container(
          padding: const EdgeInsets.all(16),
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
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (_isFormComplete && !_isSubmitting)
                  ? _submitMapping
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: const Color(0xFF0A183D),
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.15),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 6,
                shadowColor: primaryColor.withValues(alpha: 0.4),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF0A183D),
                        ),
                      ),
                    )
                  : const Text(
                      'SAVE SITE MAPPING',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
