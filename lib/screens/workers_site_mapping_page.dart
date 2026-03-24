import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';

class WorkerMappingPage extends StatefulWidget {
  const WorkerMappingPage({super.key});

  @override
  _WorkerMappingPageState createState() => _WorkerMappingPageState();
}

class _WorkerMappingPageState extends State<WorkerMappingPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Selected values
  String? _selectedSite;
  String? _selectedSupervisor;
  String? _selectedProjectName;

  // Selected worker for current selection
  String? _selectedWorker;
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
      final querySnapshot = await _firestore
          .collection('siteSupervisorMap')
          .get();
      setState(() {
        _sites = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'site': data['site'] ?? '',
            'supervisor': data['supervisor'] ?? '',
            'projectName': data['projectName'] ?? '',
          };
        }).toList();
        _isLoadingSites = false;
      });
    } catch (e) {
      print('Error loading sites: $e');
      setState(() {
        _isLoadingSites = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading sites: $e')));
    }
  }

  Future<void> _loadWorkers() async {
    setState(() {
      _isLoadingWorkers = true;
    });

    try {
      final querySnapshot = await FirestoreService.getCollection('workersConfig').get();
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
      print('Error loading workers: $e');
      setState(() {
        _isLoadingWorkers = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading workers: $e')));
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
      // Find the selected site details
      final selectedSiteData = _sites.firstWhere(
        (siteData) => siteData['site'] == site,
        orElse: () => {},
      );

      if (selectedSiteData.isNotEmpty) {
        setState(() {
          _selectedSupervisor = selectedSiteData['supervisor'];
          _selectedProjectName = selectedSiteData['projectName'];
        });

        // Load existing workers for this site if any
        _loadExistingWorkersForSite(site);
      }
    }
  }

  Future<void> _loadExistingWorkersForSite(String site) async {
    try {
      final doc = await FirestoreService.getCollection('workerSiteMap').doc(site).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final existingWorkers = List<Map<String, dynamic>>.from(
          data['workers'] ?? [],
        );

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
    } catch (e) {
      print('Error loading existing workers: $e');
    }
  }

  void _onWorkerSelected(String? workerName) {
    setState(() {
      _selectedWorker = workerName;
      _selectedWorkerDesignation = null;
      _selectedWorkerSalary = null;
      _selectedWorkerPhone = null;
    });

    if (workerName != null) {
      // Find the selected worker details
      final selectedWorkerData = _workers.firstWhere(
        (worker) => worker['name'] == workerName,
        orElse: () => {},
      );

      if (selectedWorkerData.isNotEmpty) {
        setState(() {
          _selectedWorkerDesignation = selectedWorkerData['designation'];
          _selectedWorkerSalary = selectedWorkerData['salary'];
          _selectedWorkerPhone = selectedWorkerData['phoneNumber'];
        });
      }
    }
  }

  void _addWorkerToList() {
    if (_selectedWorker == null || _selectedWorkerDesignation == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please select a worker first')));
      return;
    }

    // Check if worker is already added in current session
    bool alreadyExists = _selectedWorkersList.any(
      (worker) => worker['workerName'] == _selectedWorker,
    );

    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Worker already added to the list')),
      );
      return;
    }

    setState(() {
      _selectedWorkersList.add({
        'workerName': _selectedWorker,
        'workerDesignation': _selectedWorkerDesignation,
        'workerSalary': _selectedWorkerSalary,
        'workerPhone': _selectedWorkerPhone,
        'addedAt': DateTime.now().toIso8601String(),
      });
    });

    // Reset current selection
    setState(() {
      _selectedWorker = null;
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
    if (_selectedSite == null ||
        _selectedSupervisor == null ||
        _selectedProjectName == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please select a site first')));
      return;
    }

    if (_selectedWorkersList.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please add at least one worker')));
      return;
    }

    try {
      // Use site name as document ID
      final docRef = FirestoreService.getCollection('workerSiteMap').doc(_selectedSite!);

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
      setState(() {
        _selectedSite = null;
        _selectedSupervisor = null;
        _selectedProjectName = null;
        _selectedWorkersList.clear();
      });
    } catch (e) {
      print('Error mapping workers: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error mapping workers: $e')));
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Worker Site Mapping'),
        backgroundColor: Color(0xFF003768),
        foregroundColor: Colors.white,
      ),
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
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF003768),
        ),
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
                      return DropdownMenuItem<String>(
                        value: site['site'] as String?,
                        child: Text(site['site'] ?? ''),
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
                    value: _selectedWorker,
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
                        : availableWorkers.map<DropdownMenuItem<String>>((
                            worker,
                          ) {
                            return DropdownMenuItem<String>(
                              value: worker['name'] as String?,
                              child: Text(worker['name'] ?? ''),
                            );
                          }).toList(),
                    onChanged: _onWorkerSelected,
                  ),
                ),
                SizedBox(width: 12),
                SizedBox(
                  height: 56, // Match the dropdown height
                  child: ElevatedButton.icon(
                    onPressed: _addWorkerToList,
                    icon: Icon(Icons.add),
                    label: Text('Add'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
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
            else if (_selectedWorker != null)
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
                    color: Color(0xFF003768),
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
            style: TextStyle(
              fontSize: 12,
              
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, )),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isFormComplete ? _submitMapping : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isFormComplete ? Color(0xFF003768) : Colors.grey,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          'Save Site Mapping',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
