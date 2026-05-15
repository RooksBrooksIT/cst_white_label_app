import 'package:demo_cst/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import '../widgets/glass_scaffold.dart';

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
    final colorScheme = Theme.of(context).colorScheme;

    return GlassScaffold(
      title: 'Worker Site Mapping',
      onBack: () => Navigator.pop(context),
      body: Padding(
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
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 12),
              fontWeight: FontWeight.w800,
              color: const Color(0xFF94A3B8),
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteSelectionSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Site Dropdown
            DropdownButtonFormField<String>(
              value: _selectedSite,
              decoration: InputDecoration(
                labelText: 'Site *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.construction),
              ),
              items: _isLoadingSites
                  ? [
                      DropdownMenuItem(
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
                        child: Text(displayName),
                      );
                    }).toList(),
              onChanged: _onSiteSelected,
            ),

            SizedBox(height: 16),

            // Auto-filled Supervisor and Project Name
            if (_selectedSupervisor != null || _selectedProjectName != null)
              Column(
                children: [
                  _buildReadOnlyField(
                    'Supervisor',
                    _selectedSupervisor ?? 'Not available',
                  ),
                  SizedBox(height: 12),
                  _buildReadOnlyField(
                    'Project Name',
                    _selectedProjectName ?? 'Not available',
                  ),
                ],
              )
            else if (_selectedSite != null)
              Text(
                'No supervisor/project details found for this site',
                style: TextStyle(color: Colors.orange),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerSelectionSection() {
    // Filter out workers that are already in the list
    final availableWorkers = _workers.where((worker) {
      return !_selectedWorkersList.any(
        (selectedWorker) => selectedWorker['workerName'] == worker['name'],
      );
    }).toList();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Worker Dropdown and Add Button Row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedWorkerId,
                    decoration: InputDecoration(
                      labelText: 'Select Worker',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    items: _isLoadingWorkers
                        ? [
                            DropdownMenuItem(
                              value: null,
                              child: Text('Loading workers...'),
                            ),
                          ]
                          
                        : availableWorkers.map<DropdownMenuItem<String>>((worker) {
                            final String name = worker['name']?.toString().trim() ?? '';
                            final String displayName = name.isNotEmpty ? name : 'Unnamed (${worker['id']})';
                            return DropdownMenuItem<String>(
                              value: worker['id'] as String?,
                              child: Text(displayName),
                            );
                          }).toList(),
                    onChanged: _onWorkerSelected,
                  ),
                ),
                SizedBox(width: 12),
                SizedBox(
                  height: 56, // Match the dropdown height
                  child: FilledButton.icon(
                    onPressed: _addWorkerToList,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(
                        0xFF22C55E,
                      ), // Professional Emerald
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Auto-filled Worker Details
            if (_selectedWorkerDesignation != null ||
                _selectedWorkerSalary != null)
              Column(
                children: [
                  _buildReadOnlyField(
                    'Designation',
                    _selectedWorkerDesignation ?? 'Not available',
                  ),
                  SizedBox(height: 12),
                  _buildReadOnlyField(
                    'Salary',
                    _selectedWorkerSalary ?? 'Not available',
                  ),
                  SizedBox(height: 12),
                  if (_selectedWorkerPhone != null)
                    _buildReadOnlyField(
                      'Phone',
                      _selectedWorkerPhone ?? 'Not available',
                    ),
                ],
              )
            else if (_selectedWorkerId != null)
              Text(
                'No details found for this worker',
                style: TextStyle(color: Colors.orange),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkersTable() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Selected Workers (${_selectedWorkersList.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                if (_selectedWorkersList.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedWorkersList.clear();
                      });
                    },
                    icon: Icon(Icons.clear_all, size: 16),
                    label: Text('Clear All'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
              ],
            ),
            SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
                  columns: [
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
                        DataCell(Text('${index + 1}')),
                        DataCell(Text(worker['workerName'] ?? '')),
                        DataCell(Text(worker['workerDesignation'] ?? '')),
                        DataCell(Text(worker['workerSalary'] ?? '')),
                        DataCell(Text(worker['workerPhone'] ?? '')),
                        DataCell(
                          IconButton(
                            icon: Icon(
                              Icons.delete,
                              color: Colors.red,
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
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Column(
      children: [
        if (!_isFormComplete && _selectedSite != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange[800]),
                  SizedBox(width: 8),
                  Text(
                    _selectedWorkersList.isEmpty
                        ? 'Add at least one worker to save mapping'
                        : 'Waiting for site details...',
                    style: TextStyle(
                      color: Colors.orange[900],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: (_isFormComplete && !_isSubmitting)
                ? _submitMapping
                : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              disabledBackgroundColor: Colors.grey[200],
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : const Text(
                    'SAVE SITE MAPPING',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
