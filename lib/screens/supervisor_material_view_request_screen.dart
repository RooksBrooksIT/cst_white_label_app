import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  static const Color primaryColor = Color(0xFF0b3470);
  static const Color secondaryColor = Color(0xFF2D9CDB);
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color cardColor = Color(0xFFFFFFFF);

  late String _currentSupervisorName;

  @override
  void initState() {
    super.initState();
    _currentSupervisorName = widget.supervisorName.trim().toLowerCase();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _queryStream() {
    final col = FirestoreService
        .getCollection('siteMaterialsRequest')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
          toFirestore: (data, _) => data,
        );

    return col.orderBy('date', descending: true).snapshots();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Material Requests',
          style: TextStyle( fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: Column(
        children: [
          // Header with stats
          // _buildHeaderSection(),
          // Search and Filter
          _buildSearchAndFilter(),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _queryStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.shade400,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading requests',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return _buildEmptyState();
                }

                final search = _searchCtrl.text.trim().toLowerCase();

                final filtered = docs.where((d) {
                  final data = d.data();

                  final documentSupervisorName = (data['supervisorName'] ?? '')
                      .toString()
                      .trim()
                      .toLowerCase();

                  final bool supervisorMatch =
                      documentSupervisorName == _currentSupervisorName;

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
                  return _buildNoResultsState();
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

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, ${widget.supervisorName}',
            style: const TextStyle(
              
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Manage your material requests',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search requests...',
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey.shade500),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            color: Colors.grey.shade400,
            size: 80,
          ),
          const SizedBox(height: 20),
          Text(
            'No Requests Found',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your material requests will appear here',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, color: Colors.grey.shade400, size: 80),
          const SizedBox(height: 20),
          Text(
            'No Matching Requests',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try changing your search or filter',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
        ],
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? _FilterChip.primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? _FilterChip.primaryColor
                  : Colors.grey.shade300,
            ),
            boxShadow: [
              BoxShadow(
                
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  static const Color primaryColor = Color(0xFF0b3470);
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

  static const Color primaryColor = Color(0xFF0b3470);
  static const Color secondaryColor = Color(0xFF2D9CDB);

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

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'immediate':
        return Colors.orange;
      case 'processing':
        return secondaryColor;
      default:
        return Colors.blueGrey;
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
    return Container(
      decoration: BoxDecoration(
        
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, secondaryColor],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
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
                        style: const TextStyle(
                          
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        date,
                        style: const TextStyle(
                          color: Colors.white70,
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
                    
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(status),  size: 16),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: const TextStyle(
                          
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
                // Project Info
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
                const Text(
                  'Materials Requested',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: primaryColor,
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
    return Row(
      children: [
        Icon(icon, color: _InfoRow.primaryColor, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static const Color primaryColor = Color(0xFF0b3470);
}

class _MaterialItem extends StatelessWidget {
  final Map<String, dynamic> item;

  const _MaterialItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = (item['materialName'] ?? '').toString();
    final qty = (item['materialQty'] ?? '').toString();
    final unit = (item['materialUnit'] ?? '').toString();
    final priority = (item['priority'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: _getPriorityColor(priority),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$qty $unit • $priority Priority',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'immediate':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.blue;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
