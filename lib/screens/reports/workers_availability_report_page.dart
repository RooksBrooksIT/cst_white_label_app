import 'package:flutter/material.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/screens/supervisor/worker_calendar_availability_page.dart';

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
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirestoreService.getCollection(
        'workersAttendance',
      ).orderBy('updatedAt', descending: true).get();

      Map<String, Map<String, dynamic>> sitesMap = {};
      int totalWorkers = 0;
      Set<String> uniqueWorkerNames = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final siteName = data['site'] ?? data['siteName'] ?? 'Unknown Site';
        final workersData = data['workers'] as Map<String, dynamic>? ?? {};

        if (!sitesMap.containsKey(siteName)) {
          sitesMap[siteName] = {
            'id': siteName,
            'site': siteName,
            'projectName': 'Attendance Records',
            'supervisor': 'Various',
            'workers': <Map<String, dynamic>>[],
          };
        }

        workersData.forEach((workerId, workerInfo) {
          final workersList =
              sitesMap[siteName]!['workers'] as List<Map<String, dynamic>>;

          bool exists = workersList.any((w) => w['workerId'] == workerId);
          if (!exists) {
            workersList.add({
              'workerName': workerId,
              'workerDesignation': workerInfo['designation'] ?? 'Worker',
              'workerSalary': workerInfo['salary'] ?? '0',
              'workerId': workerId,
              'lastAttendance': workerInfo['attendance'],
              'lastUpdated': data['updatedAt'],
            });
            uniqueWorkerNames.add(workerId);
          }
        });
      }

      final mappings = sitesMap.values.toList();
      totalWorkers = uniqueWorkerNames.length;

      if (!mounted) return;
      setState(() {
        _siteMappings = mappings;
        _totalWorkersCount = totalWorkers;
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
    bool isMobile = MediaQuery.of(context).size.width < 600;
    final primaryColor = Theme.of(context).primaryColor;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final selectedMapping = _selectedMapping;
    final workers = List<Map<String, dynamic>>.from(
      selectedMapping?['workers'] ?? [],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Workers Availability',
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
            constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 650),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      _buildSummaryHeader(primaryColor),
                      _buildSearchAndFilter(primaryColor),
                      if (selectedMapping != null && selectedMapping.isNotEmpty)
                        _buildSiteInfoSection(selectedMapping, primaryColor),
                      Expanded(
                        child: selectedMapping == null || selectedMapping.isEmpty
                            ? _buildEmptyState(primaryColor)
                            : _buildWorkerList(
                                workers.where((w) {
                                  final name =
                                      w['workerName']?.toString().toLowerCase() ?? '';
                                  return name.contains(_searchQuery.toLowerCase());
                                }).toList(),
                                primaryColor,
                              ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryStat(
              'Total Sites',
              _siteMappings.length.toString(),
              Icons.location_city_rounded,
              primaryColor,
            ),
          ),
          Container(
            height: 36,
            width: 1,
            color: const Color(0xFFE2E8F0),
          ),
          Expanded(
            child: _buildSummaryStat(
              'Total Workers',
              _totalWorkersCount.toString(),
              Icons.people_alt_rounded,
              primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, IconData icon, Color primaryColor) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: primaryColor, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF0A183D),
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 2, child: _buildSiteDropdown(primaryColor)),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFCBD5E1)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A183D).withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(
                  color: Color(0xFF0A183D),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Search worker...',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: primaryColor,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteDropdown(Color primaryColor) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: _selectedSiteId,
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(14),
        icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF0A183D)),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          prefixIcon: Icon(Icons.location_on_rounded, color: primaryColor, size: 18),
        ),
        hint: const Text(
          'Select Site',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w600,
          ),
        ),
        style: const TextStyle(
          color: Color(0xFF0A183D),
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
        items: _siteMappings.map((m) {
          final siteId = m['site'] ?? m['id'];
          return DropdownMenuItem<String>(
            value: m['id'] as String?,
            child: Text(
              '$siteId',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5),
            ),
          );
        }).toList(),
        onChanged: (v) => setState(() => _selectedSiteId = v),
      ),
    );
  }

  Widget _buildSiteInfoSection(
    Map<String, dynamic> mapping,
    Color primaryColor,
  ) {
    final supervisor = mapping['supervisor'] ?? 'Not Assigned';
    final workerCount = (mapping['workers'] as List).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.person_pin_rounded,
            size: 18,
            color: primaryColor,
          ),
          const SizedBox(width: 6),
          const Text(
            'Supervisor: ',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
          Text(
            supervisor,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: primaryColor,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$workerCount Total',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerList(
    List<Map<String, dynamic>> workers,
    Color primaryColor,
  ) {
    if (workers.isEmpty) {
      return const Center(
        child: Text(
          'No workers mapped to this site',
          style: TextStyle(
            color: Color(0xFF0A183D),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: workers.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final worker = workers[index];

        final mapping = _selectedMapping;
        final workerName = worker['workerName'] ?? 'Unnamed worker';
        final siteId = mapping?['site'] ?? mapping?['id'] ?? 'Unknown';
        final workerId =
            worker['workerId']?.toString() ?? '${workerName}_$siteId';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCBD5E1)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            onTap: () {
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
              backgroundColor: primaryColor.withValues(alpha: 0.12),
              child: Text(
                (worker['workerName'] ?? 'W')[0].toUpperCase(),
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    worker['workerName'] ?? 'Unnamed worker',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Color(0xFF0A183D),
                    ),
                  ),
                ),
                _buildStatusBadge(worker['lastAttendance'] ?? ''),
              ],
            ),
            subtitle: Text(
              worker['workerDesignation'] ?? 'Worker',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${worker['workerSalary']}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: primaryColor,
                  ),
                ),
                const Text(
                  'Daily Wage',
                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color textColor;
    Color bgColor;
    String text = status.toUpperCase();

    if (status.isEmpty) {
      textColor = const Color(0xFF64748B);
      bgColor = const Color(0xFFF1F5F9);
      text = "NO DATA";
    } else {
      switch (status.toLowerCase()) {
        case 'present':
          textColor = const Color(0xFF059669);
          bgColor = const Color(0xFFDCFCE7);
          break;
        case 'absent':
          textColor = const Color(0xFFDC2626);
          bgColor = const Color(0xFFFEE2E2);
          break;
        case 'half day':
        case 'half-day':
          textColor = const Color(0xFFD97706);
          bgColor = const Color(0xFFFFEDD5);
          break;
        default:
          textColor = const Color(0xFF2563EB);
          bgColor = const Color(0xFFDBEAFE);
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_search_rounded,
              size: 48,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No matching site mappings found',
            style: TextStyle(
              color: Color(0xFF0A183D),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
