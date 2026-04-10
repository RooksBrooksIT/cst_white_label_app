import 'package:flutter/material.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/widgets/glass_card.dart';
import 'worker_calendar_availability_page.dart';

class WorkersAvailabilityReportPage extends StatefulWidget {
  const WorkersAvailabilityReportPage({super.key});

  @override
  _WorkersAvailabilityReportPageState createState() =>
      _WorkersAvailabilityReportPageState();
}

class _WorkersAvailabilityReportPageState
    extends State<WorkersAvailabilityReportPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _siteMappings = [];
  int _totalWorkersCount = 0;

  String? _selectedSiteId;

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirestoreService.getCollection(
        'workerSiteMap',
      ).get();

      int totalCount = 0;
      final mappings = snapshot.docs.map((doc) {
        final data = doc.data();
        final workers = List<Map<String, dynamic>>.from(data['workers'] ?? []);
        totalCount += workers.length;

        return {'id': doc.id, ...data, 'workers': workers};
      }).toList();

      if (!mounted) return;
      setState(() {
        _siteMappings = mappings;
        _totalWorkersCount = totalCount;
        _isLoading = false;
        if (_siteMappings.isNotEmpty) {
          _selectedSiteId = _siteMappings.first['id'];
        }
      });
    } catch (e) {
      debugPrint('Error loading availability report: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading report: $e')));
      }
    }
  }

  Map<String, dynamic>? get _selectedMapping {
    if (_selectedSiteId == null) return null;
    return _siteMappings.firstWhere(
      (m) => m['id'] == _selectedSiteId,
      orElse: () => {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedMapping = _selectedMapping;
    final workers = List<Map<String, dynamic>>.from(
      selectedMapping?['workers'] ?? [],
    );

    return GlassScaffold(
      title: 'Workers Availability',
      onBack: () => Navigator.pop(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryHeader(colorScheme),
                _buildSiteDropdown(colorScheme),
                if (selectedMapping != null && selectedMapping.isNotEmpty)
                  _buildSiteInfoSection(selectedMapping, colorScheme),
                Expanded(
                  child: selectedMapping == null || selectedMapping.isEmpty
                      ? _buildEmptyState()
                      : _buildWorkerList(workers, colorScheme),
                ),
              ],
            ),
    );
  }

  Widget _buildSiteDropdown(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: DropdownButtonFormField<String>(
        value: _selectedSiteId,
        decoration: InputDecoration(
          labelText: 'Select Site',
          prefixIcon: Icon(
            Icons.location_on_rounded,
            color: colorScheme.primary,
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        items: _siteMappings.map((m) {
          final projectName = m['projectName'] ?? 'No Project Name';
          final siteId = m['site'] ?? m['id'];
          return DropdownMenuItem<String>(
            value: m['id'] as String?,
            child: Text(
              '$siteId ($projectName)',
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: (v) => setState(() => _selectedSiteId = v),
        dropdownColor: Colors.white,
        isExpanded: true,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _buildSiteInfoSection(
    Map<String, dynamic> mapping,
    ColorScheme colorScheme,
  ) {
    final supervisor = mapping['supervisor'] ?? 'Not Assigned';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.person_pin_rounded, size: 16, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            'Supervisor: ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          Text(
            supervisor,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${(mapping['workers'] as List).length} Total',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerList(
    List<Map<String, dynamic>> workers,
    ColorScheme colorScheme,
  ) {
    if (workers.isEmpty) {
      return const Center(child: Text('No workers mapped to this site'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: workers.length,
      itemBuilder: (context, index) {
        final worker = workers[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            child: ListTile(
              onTap: () {
                final mapping = _selectedMapping;
                final workerName = worker['workerName'] ?? 'Unnamed worker';
                final siteId = mapping?['site'] ?? mapping?['id'] ?? 'Unknown';
                final workerId =
                    worker['workerId']?.toString() ?? '${workerName}_$siteId';

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WorkerCalendarAvailabilityPage(
                      workerId: workerId,
                      workerName: workerName,
                      workerDesignation:
                          worker['workerDesignation'] ?? 'Worker',
                      siteId: siteId.toString(),
                    ),
                  ),
                );
              },
              leading: CircleAvatar(
                backgroundColor: colorScheme.primary.withOpacity(0.1),
                child: Text(
                  (worker['workerName'] ?? 'W')[0],
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                worker['workerName'] ?? 'Unnamed worker',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(worker['workerDesignation'] ?? 'Worker'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${worker['workerSalary']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF22C55E),
                    ),
                  ),
                  const Text(
                    'Salary',
                    style: TextStyle(fontSize: 9, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryHeader(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildSummaryStat(
            'Total Sites',
            _siteMappings.length.toString(),
            Icons.location_city_rounded,
          ),
          const Spacer(),
          Container(height: 40, width: 1, color: Colors.white.withOpacity(0.3)),
          const Spacer(),
          _buildSummaryStat(
            'Total Workers',
            _totalWorkersCount.toString(),
            Icons.people_alt_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search_rounded,
            size: 64,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No matching site mappings found',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }
}
