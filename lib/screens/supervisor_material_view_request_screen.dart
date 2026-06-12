import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';

class SupervisorMaterialViewRequestScreen extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;

  const SupervisorMaterialViewRequestScreen({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  State<SupervisorMaterialViewRequestScreen> createState() =>
      _SupervisorMaterialViewRequestScreenState();
}

class _SupervisorMaterialViewRequestScreenState
    extends State<SupervisorMaterialViewRequestScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _statusFilter = 'All';
  List<String> _assignedSiteNames = [];
  bool _isLoadingSites = true;

  @override
  void initState() {
    super.initState();
    _fetchAssignedSites();
  }

  Future<void> _fetchAssignedSites() async {
    try {
      final collection = FirestoreService.getCollection('siteSupervisorMap');
      final snapshot = await collection
          .where('Supervisor ID', isEqualTo: widget.supervisorId)
          .get();

      final names = snapshot.docs
          .map((doc) => doc.data()['supervisor']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      if (mounted) {
        setState(() {
          _assignedSiteNames = names;
          _isLoadingSites = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSites = false);
      }
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _queryStream() {
    return FirestoreService.getCollection('siteMaterialsRequest').snapshots();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GlassScaffold(
      title: 'Material Requests',
      body: Column(
        children: [
          if (!FirestoreService.isReady)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Firestore is not initialized. Please re-login.',
                style: TextStyle(color: cs.onErrorContainer),
                textAlign: TextAlign.center,
              ),
            ),
          _buildSearchAndFilter(cs),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _queryStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: cs.error, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading requests',
                          style: TextStyle(
                            color: cs.onSurface.withOpacity(0.6),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: cs.error.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return _buildEmptyState(cs);
                }

                final search = _searchCtrl.text.trim().toLowerCase();

                final filtered = docs.where((d) {
                  final data = d.data();

                  final documentSupervisorName =
                      (data['supervisorName'] ??
                              data['supervisor'] ??
                              data['Supervisor Name'] ??
                              data['supervisor_name'] ??
                              data['Name'] ??
                              '')
                          .toString()
                          .trim()
                          .toLowerCase();
                  final documentSupervisorId = (data['supervisorId'] ?? '')
                      .toString()
                      .trim()
                      .toLowerCase();

                  // Match by ID if available, otherwise by Name
                  bool supervisorMatch = false;

                  final searchId = widget.supervisorId.trim().toLowerCase();
                  final searchName = widget.supervisorName.trim().toLowerCase();

                  // 1. Check ID Match
                  if (documentSupervisorId.isNotEmpty && searchId.isNotEmpty) {
                    supervisorMatch = documentSupervisorId == searchId;
                  }

                  // 2. Check Name Match (permissive)
                  if (!supervisorMatch) {
                    final List<String> validNames = [
                      searchName,
                      ..._assignedSiteNames.map((e) => e.toLowerCase()),
                    ];

                    supervisorMatch = validNames.any(
                      (name) =>
                          documentSupervisorName == name ||
                          (documentSupervisorName.isNotEmpty &&
                              name.isNotEmpty &&
                              (documentSupervisorName.contains(name) ||
                                  name.contains(documentSupervisorName))),
                    );
                  }

                  if (!supervisorMatch) {
                    return false;
                  }

                  final matReqId = (data['matReqId'] ?? '')
                      .toString()
                      .toLowerCase();
                  final status = (data['status'] ?? '')
                      .toString()
                      .toLowerCase();
                  final projectName = (data['projectName'] ?? '')
                      .toString()
                      .toLowerCase();
                  final siteId = (data['siteId'] ?? '')
                      .toString()
                      .toLowerCase();

                  final matchesStatus =
                      _statusFilter.toLowerCase() == 'all' ||
                      status == _statusFilter.toLowerCase();
                  final matchesSearch =
                      search.isEmpty ||
                      matReqId.contains(search) ||
                      status.contains(search) ||
                      projectName.contains(search) ||
                      siteId.contains(search);

                  return matchesStatus && matchesSearch;
                }).toList();

                if (filtered.isEmpty) {
                  return _buildNoResultsState(cs);
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final data = doc.data();

                    final String matReqId = (data['matReqId'] ?? '').toString();
                    final rawDate = data['date'];
                    String dateStr = '';
                    if (rawDate is Timestamp) {
                      dateStr = DateFormat(
                        'MMM dd, yyyy • hh:mm a',
                      ).format(rawDate.toDate());
                    } else if (rawDate is String) {
                      dateStr = rawDate;
                    } else {
                      dateStr = rawDate?.toString() ?? '';
                    }

                    final List materials = (data['materials'] is List)
                        ? (data['materials'] as List)
                        : const [];

                    final String status = (data['status'] ?? '').toString();
                    final String projectName = (data['projectName'] ?? '')
                        .toString();
                    final String siteId = (data['siteId'] ?? '').toString();
                    final String projectStage = (data['projectStage'] ?? '')
                        .toString();
                    final String supervisorName = (data['supervisorName'] ?? '')
                        .toString();

                    return _RequestCard(
                      matReqId: matReqId,
                      date: dateStr,
                      status: status,
                      projectName: projectName,
                      siteId: siteId,
                      projectStage: projectStage,
                      supervisorName: supervisorName,
                      materials: materials,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: cs.surface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'Search requests...',
                hintStyle: TextStyle(color: cs.onSurface.withOpacity(0.5)),
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                border: InputBorder.none,
                prefixIcon: Icon(
                  Icons.search,
                  color: cs.onSurface.withOpacity(0.5),
                ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: cs.onSurface.withOpacity(0.5),
                        ),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Filter Chips
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  label: 'All',
                  isSelected: _statusFilter == 'All',
                  onTap: () => setState(() => _statusFilter = 'All'),
                ),
                _FilterChip(
                  label: 'Approved',
                  isSelected: _statusFilter == 'Approved',
                  onTap: () => setState(() => _statusFilter = 'Approved'),
                ),
                _FilterChip(
                  label: 'Processing',
                  isSelected: _statusFilter == 'Processing',
                  onTap: () => setState(() => _statusFilter = 'Processing'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            color: cs.onSurface.withOpacity(0.3),
            size: 80,
          ),
          const SizedBox(height: 20),
          Text(
            'No Requests Found',
            style: TextStyle(
              color: cs.onSurface.withOpacity(0.6),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your material requests will appear here',
            style: TextStyle(
              color: cs.onSurface.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState(ColorScheme cs) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              color: cs.onSurface.withOpacity(0.3),
              size: 80,
            ),
            const SizedBox(height: 20),
            Text(
              'No Matching Requests',
              style: TextStyle(
                color: cs.onSurface.withOpacity(0.6),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'For: ${widget.supervisorName}',
              style: TextStyle(
                color: cs.onSurface.withOpacity(0.4),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Try changing your search or filter',
              style: TextStyle(
                color: cs.onSurface.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () {
                _searchCtrl.clear();
                setState(() => _statusFilter = 'All');
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reset Filters'),
              style: TextButton.styleFrom(
                foregroundColor: cs.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: cs.primary.withOpacity(0.3)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? cs.primary : cs.surface.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? cs.primary : cs.outlineVariant,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? cs.onPrimary : cs.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final String matReqId;
  final String date;
  final String status;
  final String projectName;
  final String siteId;
  final String projectStage;
  final String supervisorName;
  final List materials;

  const _RequestCard({
    super.key,
    required this.matReqId,
    required this.date,
    required this.status,
    required this.projectName,
    required this.siteId,
    required this.projectStage,
    required this.supervisorName,
    required this.materials,
  });

  Color _statusColor(BuildContext context, String s) {
    switch (s.toLowerCase()) {
      case 'approved':
        return Colors.green; // Semantic success
      case 'rejected':
        return Theme.of(context).colorScheme.error;
      case 'immediate':
        return Colors.orange; // Semantic warning
      case 'processing':
        return Theme.of(context).colorScheme.secondary;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String s) {
    switch (s.toLowerCase()) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'immediate':
        return Icons.warning;
      case 'processing':
        return Icons.hourglass_empty;
      default:
        return Icons.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Header with gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.secondary],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Request ID: $matReqId',
                        style: TextStyle(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        date,
                        style: TextStyle(
                          color: cs.onPrimary.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: cs.onPrimary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(status), color: cs.onPrimary, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  icon: Icons.business,
                  label: 'Project',
                  value: projectName,
                ),
                const SizedBox(height: 8),
                _InfoRow(icon: Icons.place, label: 'Site ID', value: siteId),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.construction,
                  label: 'Stage',
                  value: projectStage,
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.person,
                  label: 'Supervisor',
                  value: supervisorName,
                ),
                const SizedBox(height: 16),
                // Materials Section
                Text(
                  'Materials Requested',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 12),
                ...materials.map((m) {
                  final item = Map<String, dynamic>.from(m as Map);
                  return _MaterialItem(item: item);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: cs.primary, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: cs.onSurface.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MaterialItem extends StatelessWidget {
  final Map<String, dynamic> item;

  const _MaterialItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = (item['materialName'] ?? '').toString();
    final qty = (item['materialQty'] ?? '').toString();
    final unit = (item['materialUnit'] ?? '').toString();
    final priority = (item['priority'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: _getPriorityColor(context, priority),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$qty $unit • $priority Priority',
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(BuildContext context, String priority) {
    switch (priority.toLowerCase()) {
      case 'immediate':
        return Theme.of(context).colorScheme.error;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Theme.of(context).colorScheme.secondary;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
