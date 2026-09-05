import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:demo_cst/services/app_storage_service.dart';
import 'package:demo_cst/services/approval_workflow_service.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';
import 'package:demo_cst/widgets/glass_card.dart';
import 'package:demo_cst/widgets/approval_lifecycle_stepper.dart';
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
  List<String> _assignedSiteNames = [];

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
        });
      }
    } catch (_) {}
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
    final primaryColor = Theme.of(context).colorScheme.primary;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final isMobile = MediaQuery.of(context).size.width < 600;

    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Material Requests',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: -0.3,
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
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isMobile ? double.infinity : 600,
          ),
          child: Column(
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
                            Icon(
                              Icons.error_outline,
                              color: cs.error,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading requests',
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.6),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                              ),
                              child: Text(
                                snapshot.error.toString(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: cs.error.withValues(alpha: 0.7),
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
                      final searchName = widget.supervisorName
                          .trim()
                          .toLowerCase();

                      // 1. Check ID Match
                      if (documentSupervisorId.isNotEmpty &&
                          searchId.isNotEmpty) {
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
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final doc = filtered[index];
                        final data = doc.data();

                        final String matReqId = (data['matReqId'] ?? '')
                            .toString();
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
                        final String supervisorName =
                            (data['supervisorName'] ?? '').toString();
                        final String supervisorId = (data['supervisorId'] ?? '')
                            .toString();

                        return _RequestCard(
                          docId: doc.id,
                          matReqId: matReqId,
                          date: dateStr,
                          status: status,
                          projectName: projectName,
                          siteId: siteId,
                          projectStage: projectStage,
                          supervisorName: supervisorName,
                          supervisorId: supervisorId,
                          currentSupervisorId: widget.supervisorId,
                          currentSupervisorName: widget.supervisorName,
                          materials: materials,
                          history: (data['approvalHistory'] is List)
                              ? (data['approvalHistory'] as List)
                              : null,
                          rejectionReason: data['rejectionReason']?.toString(),
                          arrivalConfirmationStatus:
                              (data['arrivalConfirmationStatus'] ?? '')
                                  .toString(),
                          arrivalConfirmedBy: (data['arrivalConfirmedBy'] ?? '')
                              .toString(),
                          arrivalConfirmedById:
                              (data['arrivalConfirmedById'] ?? '').toString(),
                          arrivalConfirmedAt: data['arrivalConfirmedAt'],
                          arrivalProofImageUrl:
                              (data['arrivalProofImageUrl'] ?? '').toString(),
                          arrivalConfirmationRemarks:
                              (data['arrivalConfirmationRemarks'] ?? '')
                                  .toString(),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
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
              color: cs.surface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'Search requests...',
                hintStyle: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                border: InputBorder.none,
                prefixIcon: Icon(
                  Icons.search,
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: cs.onSurface.withValues(alpha: 0.5),
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
            color: cs.onSurface.withValues(alpha: 0.3),
            size: 80,
          ),
          const SizedBox(height: 20),
          Text(
            'No Requests Found',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.6),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your material requests will appear here',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.5),
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
              color: cs.onSurface.withValues(alpha: 0.3),
              size: 80,
            ),
            const SizedBox(height: 20),
            Text(
              'No Matching Requests',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.6),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'For: ${widget.supervisorName}',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.4),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Try changing your search or filter',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () {
                _searchCtrl.clear();
                setState(() => _statusFilter = 'All');
              },
              icon: const Icon(Icons.filter_alt_off_rounded),
              label: const Text('Reset Filters'),
              style: TextButton.styleFrom(
                foregroundColor: cs.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: cs.primary.withValues(alpha: 0.3)),
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
            color: isSelected ? cs.primary : cs.surface.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? cs.primary : cs.outlineVariant,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? cs.onPrimary
                  : cs.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final String docId;
  final String matReqId;
  final String date;
  final String status;
  final String projectName;
  final String siteId;
  final String projectStage;
  final String supervisorName;
  final String supervisorId;
  final String currentSupervisorId;
  final String currentSupervisorName;
  final List materials;
  final List<dynamic>? history;
  final String? rejectionReason;
  final String arrivalConfirmationStatus;
  final String arrivalConfirmedBy;
  final String arrivalConfirmedById;
  final dynamic arrivalConfirmedAt;
  final String arrivalProofImageUrl;
  final String arrivalConfirmationRemarks;

  const _RequestCard({
    required this.docId,
    required this.matReqId,
    required this.date,
    required this.status,
    required this.projectName,
    required this.siteId,
    required this.projectStage,
    required this.supervisorName,
    required this.supervisorId,
    required this.currentSupervisorId,
    required this.currentSupervisorName,
    required this.materials,
    this.history,
    this.rejectionReason,
    this.arrivalConfirmationStatus = '',
    this.arrivalConfirmedBy = '',
    this.arrivalConfirmedById = '',
    this.arrivalConfirmedAt,
    this.arrivalProofImageUrl = '',
    this.arrivalConfirmationRemarks = '',
  });

  bool get isApproved =>
      ApprovalWorkflowService.parseStatus(status) == ApprovalStage.approved;
  bool get isArrivalConfirmed =>
      arrivalConfirmationStatus.toLowerCase() == 'confirmed';

  bool get isRequestingSupervisor {
    final cId = currentSupervisorId.trim().toLowerCase();
    final sId = supervisorId.trim().toLowerCase();
    if (cId.isNotEmpty && sId.isNotEmpty && cId == sId) return true;

    final cName = currentSupervisorName.trim().toLowerCase();
    final sName = supervisorName.trim().toLowerCase();
    if (cName.isNotEmpty &&
        sName.isNotEmpty &&
        (cName == sName || cName.contains(sName) || sName.contains(cName))) {
      return true;
    }
    return false;
  }

  IconData _statusIcon(String s) {
    if (isApproved) {
      return isArrivalConfirmed
          ? Icons.verified_rounded
          : Icons.local_shipping_rounded;
    }
    switch (s.toLowerCase()) {
      case 'rejected':
      case 'rejected_by_manager':
      case 'rejected_by_org':
        return Icons.cancel;
      case 'immediate':
        return Icons.warning;
      case 'processing':
        return Icons.hourglass_empty;
      default:
        return Icons.pending;
    }
  }

  String _formatConfirmedDate(dynamic raw) {
    if (raw == null) return '';
    if (raw is Timestamp) {
      return DateFormat('MMM dd, yyyy • hh:mm a').format(raw.toDate());
    }
    if (raw is String && raw.isNotEmpty) return raw;
    return raw.toString();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String displayBadgeText;
    if (isApproved) {
      displayBadgeText = isArrivalConfirmed
          ? 'MATERIAL RECEIVED'
          : 'AWAITING ARRIVAL';
    } else {
      displayBadgeText = ApprovalWorkflowService.getStatusDisplayText(
        status,
      ).toUpperCase();
    }

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
                colors: isApproved && isArrivalConfirmed
                    ? [const Color(0xFF059669), const Color(0xFF10B981)]
                    : (isApproved
                          ? [const Color(0xFFD97706), const Color(0xFFF59E0B)]
                          : [cs.primary, cs.secondary]),
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
                          color: cs.onPrimary.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: cs.onPrimary.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(status), color: cs.onPrimary, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        displayBadgeText,
                        style: TextStyle(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
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
                const SizedBox(height: 14),

                // Multi-Stage Visual Lifecycle Stepper
                ApprovalLifecycleStepper(
                  status: status,
                  history: history,
                  isCompact: false,
                  rejectionReason: rejectionReason,
                ),
                const SizedBox(height: 16),

                // Materials Section
                Text(
                  'Materials Requested & Released',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 10),
                ...materials.map((m) {
                  final item = Map<String, dynamic>.from(m as Map);
                  return _MaterialItem(item: item);
                }),

                // =============================================================
                // POST-RELEASE: MATERIAL ARRIVAL CONFIRMATION SECTION
                // =============================================================
                if (isApproved) ...[
                  const SizedBox(height: 14),
                  if (isArrivalConfirmed)
                    _buildConfirmedArrivalCard(context)
                  else
                    _buildPendingArrivalCard(context),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Confirmed Arrival Card ---
  Widget _buildConfirmedArrivalCard(BuildContext context) {
    final confirmedDateStr = _formatConfirmedDate(arrivalConfirmedAt);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFF16A34A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Material Received / Arrival Confirmed',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF166534),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Text(
                  'VERIFIED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                size: 14,
                color: Color(0xFF15803D),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Confirmed By: ${arrivalConfirmedBy.isNotEmpty ? arrivalConfirmedBy : supervisorName}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF14532D),
                  ),
                ),
              ),
            ],
          ),
          if (confirmedDateStr.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: Color(0xFF15803D),
                ),
                const SizedBox(width: 4),
                Text(
                  confirmedDateStr,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF166534),
                  ),
                ),
              ],
            ),
          ],
          if (arrivalConfirmationRemarks.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Text(
                'Notes: $arrivalConfirmationRemarks',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
          ],
          if (arrivalProofImageUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () =>
                  _showImagePreviewDialog(context, arrivalProofImageUrl),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                  color: Colors.white,
                ),
                padding: const EdgeInsets.all(6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        arrivalProofImageUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 48,
                          height: 48,
                          color: const Color(0xFFE2E8F0),
                          child: const Icon(
                            Icons.broken_image,
                            size: 20,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Arrival Proof Photo',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF166534),
                          ),
                        ),
                        SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.zoom_in_rounded,
                              size: 13,
                              color: Color(0xFF15803D),
                            ),
                            SizedBox(width: 3),
                            Text(
                              'Tap to inspect photo',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF15803D),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Pending Arrival Card ---
  Widget _buildPendingArrivalCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCD34D), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFD97706),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Material Arrival Confirmation',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Text(
                  'AWAITING ARRIVAL',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Material has been released by Manager. When it physically arrives at the site, upload a proof photo to confirm arrival.',
            style: TextStyle(
              fontSize: 11.5,
              color: Color(0xFF78350F),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          if (isRequestingSupervisor)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt_rounded, size: 16),
                label: const Text(
                  'Confirm Material Arrival',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _showArrivalConfirmationModal(context),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: Color(0xFFB45309),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Arrival confirmation can only be submitted by $supervisorName.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // --- Modal Bottom Sheet for Arrival Confirmation ---
  void _showArrivalConfirmationModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _ArrivalConfirmationSheet(
        docId: docId,
        matReqId: matReqId,
        siteId: siteId,
        supervisorName: supervisorName,
        supervisorId: supervisorId,
        currentSupervisorName: currentSupervisorName,
        currentSupervisorId: currentSupervisorId,
        materials: materials,
      ),
    );
  }

  void _showImagePreviewDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
                errorBuilder: (_, _, _) => Container(
                  padding: const EdgeInsets.all(32),
                  color: Colors.white,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.broken_image_rounded,
                        size: 48,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 8),
                      Text('Failed to load image preview'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArrivalConfirmationSheet extends StatefulWidget {
  final String docId;
  final String matReqId;
  final String siteId;
  final String supervisorName;
  final String supervisorId;
  final String currentSupervisorName;
  final String currentSupervisorId;
  final List materials;

  const _ArrivalConfirmationSheet({
    required this.docId,
    required this.matReqId,
    required this.siteId,
    required this.supervisorName,
    required this.supervisorId,
    required this.currentSupervisorName,
    required this.currentSupervisorId,
    required this.materials,
  });

  @override
  State<_ArrivalConfirmationSheet> createState() =>
      _ArrivalConfirmationSheetState();
}

class _ArrivalConfirmationSheetState extends State<_ArrivalConfirmationSheet> {
  final TextEditingController _remarksController = TextEditingController();
  File? _pickedImage;
  bool _isSubmitting = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (file != null) {
        setState(() {
          _pickedImage = File(file.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error selecting image: $e')));
      }
    }
  }

  Future<void> _confirmArrival() async {
    if (_pickedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload or capture an arrival proof image.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 1. Upload arrival proof image using AppStorageService
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${widget.matReqId}_arrival_$timestamp.jpg';

      final uploadResult = await AppStorageService.uploadFile(
        category: 'material_arrival_proof',
        fileName: fileName,
        file: _pickedImage,
      );

      final proofUrl = uploadResult?.downloadUrl ?? '';

      // 2. Call ApprovalWorkflowService to confirm physical arrival
      await ApprovalWorkflowService.supervisorConfirmArrival(
        collectionName: 'siteMaterialsRequest',
        docId: widget.docId,
        supervisorName: widget.currentSupervisorName.isNotEmpty
            ? widget.currentSupervisorName
            : widget.supervisorName,
        supervisorId: widget.currentSupervisorId.isNotEmpty
            ? widget.currentSupervisorId
            : widget.supervisorId,
        proofImageUrl: proofUrl,
        remarks: _remarksController.text.trim(),
        siteId: widget.siteId,
        matReqId: widget.matReqId,
      );

      if (!mounted) return;

      Navigator.pop(context); // Close bottom sheet

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF059669),
                size: 26,
              ),
              SizedBox(width: 8),
              Text('Arrival Confirmed!'),
            ],
          ),
          content: Text(
            'Material physical arrival for Requisition ${widget.matReqId} has been successfully confirmed with proof image. Managers have been notified.',
            style: const TextStyle(fontSize: 13.5),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to confirm arrival: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    color: Color(0xFF059669),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Confirm Material Arrival',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Requisition: ${widget.matReqId} • Site: ${widget.siteId}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Material Items Summary
            const Text(
              'Released Materials to Verify:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: widget.materials.map((m) {
                  final item = Map<String, dynamic>.from(m as Map);
                  final name = item['materialName']?.toString() ?? 'Material';
                  final qty = item['materialQty']?.toString() ?? '0';
                  final unit = item['materialUnit']?.toString() ?? 'Units';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '• $name',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$qty $unit',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Proof Image Upload Box (Mandatory)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Arrival Proof Photo *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
                Text(
                  _pickedImage != null ? 'Photo Ready ✓' : 'Required',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _pickedImage != null
                        ? const Color(0xFF059669)
                        : const Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_pickedImage == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFCBD5E1),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.add_a_photo_outlined,
                      size: 36,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Capture or upload arrival proof photo',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(
                              Icons.camera_alt_rounded,
                              size: 16,
                            ),
                            label: const Text(
                              'Camera',
                              style: TextStyle(fontSize: 12.5),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2563EB),
                              side: const BorderSide(color: Color(0xFF93C5FD)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => _pickImage(ImageSource.camera),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(
                              Icons.photo_library_rounded,
                              size: 16,
                            ),
                            label: const Text(
                              'Gallery',
                              style: TextStyle(fontSize: 12.5),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF059669),
                              side: const BorderSide(color: Color(0xFF86EFAC)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => _pickImage(ImageSource.gallery),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _pickedImage!,
                            width: double.infinity,
                            height: 180,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: InkWell(
                            onTap: () => setState(() => _pickedImage = null),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.refresh_rounded, size: 15),
                          label: const Text('Retake Photo'),
                          onPressed: () => _pickImage(ImageSource.camera),
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          icon: const Icon(
                            Icons.photo_library_outlined,
                            size: 15,
                          ),
                          label: const Text('Choose Another'),
                          onPressed: () => _pickImage(ImageSource.gallery),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Optional Remarks
            const Text(
              'Remarks / Notes (Optional)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _remarksController,
              decoration: InputDecoration(
                hintText:
                    'e.g. Received 200 bags in undamaged condition, vehicle #MH12-3456.',
                hintStyle: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
                onPressed: _isSubmitting ? null : _confirmArrival,
                child: _isSubmitting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text('Uploading & Confirming...'),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Confirm Material Arrived',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
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
                  color: cs.onSurface.withValues(alpha: 0.6),
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
        color: cs.surface.withValues(alpha: 0.3),
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
                    color: cs.onSurface.withValues(alpha: 0.6),
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
