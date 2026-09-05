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

class SupervisorToolsViewRequestScreen extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;

  const SupervisorToolsViewRequestScreen({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  State<SupervisorToolsViewRequestScreen> createState() =>
      _SupervisorToolsViewRequestScreenState();
}

class _SupervisorToolsViewRequestScreenState
    extends State<SupervisorToolsViewRequestScreen> {
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
    return FirestoreService.getCollection('siteToolsRequest').snapshots();
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
          'Tools Requisitions',
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
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
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
                            Icon(Icons.error_outline, color: cs.error, size: 64),
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
                              padding: const EdgeInsets.symmetric(horizontal: 32),
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

                      bool supervisorMatch = false;

                      final searchId = widget.supervisorId.trim().toLowerCase();
                      final searchName = widget.supervisorName.trim().toLowerCase();

                      if (documentSupervisorId.isNotEmpty && searchId.isNotEmpty) {
                        supervisorMatch = documentSupervisorId == searchId;
                      }

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

                      final toolReqId = (data['toolReqId'] ?? '')
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

                      final stage = ApprovalWorkflowService.parseStatus(status);

                      if (_statusFilter == 'Pending' &&
                          stage != ApprovalStage.pendingManagerReview &&
                          stage != ApprovalStage.pendingOrgApproval &&
                          stage != ApprovalStage.pendingManagerClearance) {
                        return false;
                      }
                      if (_statusFilter == 'Approved' &&
                          stage != ApprovalStage.approved) {
                        return false;
                      }
                      if (_statusFilter == 'Rejected' &&
                          stage != ApprovalStage.rejectedByManager &&
                          stage != ApprovalStage.rejectedByOrg) {
                        return false;
                      }

                      if (search.isNotEmpty) {
                        final matchesId = toolReqId.contains(search);
                        final matchesProject = projectName.contains(search);
                        final matchesSite = siteId.contains(search);
                        final toolsList = data['tools'] as List<dynamic>?;
                        final matchesTool = toolsList?.any((tool) {
                              final name = (tool['toolName'] ?? tool['name'] ?? tool['toolCode'] ?? '')
                                  .toString()
                                  .toLowerCase();
                              return name.contains(search);
                            }) ??
                            false;

                        if (!matchesId &&
                            !matchesProject &&
                            !matchesSite &&
                            !matchesTool) {
                          return false;
                        }
                      }

                      return true;
                    }).toList();

                    if (filtered.isEmpty) {
                      return _buildEmptyState(cs);
                    }

                    filtered.sort((a, b) {
                      final aDate = a.data()['createdAt'] as Timestamp?;
                      final bDate = b.data()['createdAt'] as Timestamp?;
                      if (aDate == null && bDate == null) return 0;
                      if (aDate == null) return 1;
                      if (bDate == null) return -1;
                      return bDate.compareTo(aDate);
                    });

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final doc = filtered[index];
                        return _buildRequestCard(context, doc.data(), doc.id);
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search by Tool ID, Tool Name, Site...',
              hintStyle: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.5),
                fontSize: 13,
              ),
              prefixIcon: Icon(Icons.search, color: cs.primary, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', cs),
                const SizedBox(width: 8),
                _buildFilterChip('Pending', cs),
                const SizedBox(width: 8),
                _buildFilterChip('Approved', cs),
                const SizedBox(width: 8),
                _buildFilterChip('Rejected', cs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, ColorScheme cs) {
    final isSelected = _statusFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() {
            _statusFilter = label;
          });
        }
      },
      selectedColor: cs.primary,
      backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
      labelStyle: TextStyle(
        color: isSelected ? cs.onPrimary : cs.onSurface,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction_outlined,
            size: 64,
            color: cs.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No tool requisitions found',
            style: TextStyle(
              fontSize: 16,
              color: cs.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(
      BuildContext context, Map<String, dynamic> data, String docId) {
    final cs = Theme.of(context).colorScheme;
    final toolReqId = (data['toolReqId'] ?? docId).toString();
    final siteId = (data['siteId'] ?? '').toString();
    final projectName = (data['projectName'] ?? '').toString();
    final status = (data['status'] ?? '').toString();
    final stage = ApprovalWorkflowService.parseStatus(status);
    final statusText = ApprovalWorkflowService.getStatusDisplayText(status);
    final date = (data['date'] ?? '').toString();
    final toolsList = data['tools'] as List<dynamic>? ?? [];

    final arrivalStatus = (data['arrivalConfirmationStatus'] ?? '').toString().toLowerCase();
    final isArrivalConfirmed = arrivalStatus == 'confirmed';
    final arrivalConfirmedBy = (data['arrivalConfirmedBy'] ?? widget.supervisorName).toString();
    final rawArrivalDate = data['arrivalConfirmedAt'];
    String arrivalDateStr = '';
    if (rawArrivalDate is Timestamp) {
      arrivalDateStr = DateFormat('MMM dd, yyyy • hh:mm a').format(rawArrivalDate.toDate());
    } else if (rawArrivalDate is String && rawArrivalDate.isNotEmpty) {
      arrivalDateStr = rawArrivalDate;
    }
    final arrivalProofImg = (data['arrivalProofImageUrl'] ?? '').toString();

    final reqSupervisorId = (data['supervisorId'] ?? data['userId'] ?? data['createdById'] ?? '').toString().trim();
    final isOriginalSupervisor = reqSupervisorId.isEmpty ||
        reqSupervisorId.toLowerCase() == widget.supervisorId.trim().toLowerCase() ||
        (data['supervisorName'] ?? '').toString().trim().toLowerCase() == widget.supervisorName.trim().toLowerCase();

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      toolReqId,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: cs.onSurface,
                      ),
                    ),
                    if (projectName.isNotEmpty)
                      Text(
                        projectName,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              _buildStatusBadge(stage, statusText, context),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: cs.primary),
              const SizedBox(width: 4),
              Text(
                siteId.isNotEmpty ? siteId : 'Site N/A',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (date.isNotEmpty) ...[
                Icon(Icons.calendar_today_outlined,
                    size: 14, color: cs.onSurface.withValues(alpha: 0.6)),
                const SizedBox(width: 4),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            'Requested Equipment (${toolsList.length}):',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 6),
          ...toolsList.map((tool) {
            if (tool is! Map) return const SizedBox.shrink();
            final name = (tool['toolName'] ?? tool['name'] ?? tool['toolCode'] ?? '').toString();
            final code = (tool['toolCode'] ?? '').toString();
            final count = (tool['toolCount'] ?? tool['count'] ?? tool['quantity'] ?? 1).toString();

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(Icons.handyman_outlined, size: 14, color: cs.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (code.isNotEmpty && code != name) ...[
                    Text(
                      code,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$count Units',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // --- TOOL ARRIVAL CONFIRMATION SECTION ---
          if (stage == ApprovalStage.approved) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isArrivalConfirmed ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isArrivalConfirmed ? const Color(0xFF86EFAC) : const Color(0xFFFCD34D),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isArrivalConfirmed ? Icons.verified_rounded : Icons.local_shipping_rounded,
                        size: 16,
                        color: isArrivalConfirmed ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isArrivalConfirmed
                              ? 'Tools Received & Arrival Confirmed'
                              : 'Awaiting Arrival Confirmation',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: isArrivalConfirmed ? const Color(0xFF166534) : const Color(0xFF92400E),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isArrivalConfirmed ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isArrivalConfirmed ? 'RECEIVED' : 'IN TRANSIT',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: isArrivalConfirmed ? const Color(0xFF15803D) : const Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (isArrivalConfirmed) ...[
                    Text(
                      'Confirmed by: $arrivalConfirmedBy ${arrivalDateStr.isNotEmpty ? '• $arrivalDateStr' : ''}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF14532D),
                      ),
                    ),
                    if (arrivalProofImg.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _showImagePreviewDialog(context, arrivalProofImg),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                arrivalProofImg,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  width: 44,
                                  height: 44,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.broken_image, size: 20, color: Colors.grey),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Arrival Proof Photo',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF166534),
                                  ),
                                ),
                                Text(
                                  'Tap to view image',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF15803D)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ] else ...[
                    const Text(
                      'Tools have been approved & released by Manager. Confirm arrival once equipment reaches site.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF78350F)),
                    ),
                    if (isOriginalSupervisor) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 38,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          icon: const Icon(Icons.camera_alt_rounded, size: 16),
                          label: const Text(
                            'Confirm Tool Arrival',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                          ),
                          onPressed: () => _openArrivalConfirmationModal(context, data, docId),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: BorderSide(color: cs.outlineVariant),
              ),
              onPressed: () => _showDetailsModal(context, data, docId),
              child: const Text('View Full Details & Timeline'),
            ),
          ),
        ],
      ),
    );
  }

  void _openArrivalConfirmationModal(
      BuildContext context, Map<String, dynamic> data, String docId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _ToolArrivalConfirmationSheet(
        data: data,
        docId: docId,
        supervisorId: widget.supervisorId,
        supervisorName: widget.supervisorName,
      ),
    );
  }

  void _showImagePreviewDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (dlgCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF0F172A),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Arrival Proof Photo',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                    onPressed: () => Navigator.pop(dlgCtx),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  },
                  errorBuilder: (_, _, _) => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        'Failed to load proof image',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(
      ApprovalStage stage, String text, BuildContext context) {
    Color bg;
    Color fg;

    switch (stage) {
      case ApprovalStage.pendingManagerReview:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        break;
      case ApprovalStage.pendingOrgApproval:
        bg = const Color(0xFFEDE9FE);
        fg = const Color(0xFF7C3AED);
        break;
      case ApprovalStage.pendingManagerClearance:
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF2563EB);
        break;
      case ApprovalStage.approved:
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF059669);
        break;
      case ApprovalStage.rejectedByManager:
      case ApprovalStage.rejectedByOrg:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showDetailsModal(
      BuildContext context, Map<String, dynamic> data, String docId) {
    final cs = Theme.of(context).colorScheme;
    final toolReqId = (data['toolReqId'] ?? docId).toString();
    final status = (data['status'] ?? '').toString();
    final statusText = ApprovalWorkflowService.getStatusDisplayText(status);
    final history = data['approvalHistory'] as List<dynamic>? ?? [];
    final toolsList = data['tools'] as List<dynamic>? ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Requisition $toolReqId',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  _buildStatusBadge(
                      ApprovalWorkflowService.parseStatus(status),
                      statusText,
                      context),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Approval Progress',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              ApprovalLifecycleStepper(
                status: status,
                history: history,
                isCompact: false,
              ),
              const SizedBox(height: 20),
              Text(
                'Equipment Items',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              ...toolsList.map((tool) {
                if (tool is! Map) return const SizedBox.shrink();
                final name = (tool['toolName'] ?? tool['name'] ?? tool['toolCode'] ?? '').toString();
                final code = (tool['toolCode'] ?? '').toString();
                final count = (tool['toolCount'] ?? tool['count'] ?? tool['quantity'] ?? 1).toString();

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.construction_rounded, color: cs.primary, size: 20),
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
                            if (code.isNotEmpty)
                              Text(
                                code,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '$count Units',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolArrivalConfirmationSheet extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;
  final String supervisorId;
  final String supervisorName;

  const _ToolArrivalConfirmationSheet({
    required this.data,
    required this.docId,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  State<_ToolArrivalConfirmationSheet> createState() =>
      _ToolArrivalConfirmationSheetState();
}

class _ToolArrivalConfirmationSheetState
    extends State<_ToolArrivalConfirmationSheet> {
  final TextEditingController _remarksController = TextEditingController();
  File? _proofImageFile;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (picked != null) {
        setState(() {
          _proofImageFile = File(picked.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Upload Tool Arrival Proof',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Capture live photo on-site or choose from gallery:',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.camera_alt_rounded, size: 18),
                      label: const Text('Camera', style: TextStyle(fontWeight: FontWeight.w700)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      icon: const Icon(Icons.photo_library_rounded, size: 18),
                      label: const Text('Gallery', style: TextStyle(fontWeight: FontWeight.w700)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmArrival() async {
    if (_proofImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload an image/photo as proof of tool arrival.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final toolsList = widget.data['tools'] as List<dynamic>?;
      final siteId = widget.data['siteId']?.toString();
      final toolReqId = (widget.data['toolReqId'] ?? widget.docId).toString();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${toolReqId}_arrival_$timestamp.jpg';

      final uploadResult = await AppStorageService.uploadFile(
        category: 'tool_arrival_proof',
        fileName: fileName,
        file: _proofImageFile!,
      );

      final downloadUrl = uploadResult?.downloadUrl ?? '';

      if (downloadUrl.isEmpty) {
        throw Exception('Failed to upload proof image to cloud storage.');
      }

      await ApprovalWorkflowService.supervisorConfirmToolArrival(
        collectionName: 'siteToolsRequest',
        docId: widget.docId,
        supervisorName: widget.supervisorName,
        supervisorId: widget.supervisorId,
        proofImageUrl: downloadUrl,
        remarks: _remarksController.text.trim(),
        siteId: siteId,
        toolReqId: toolReqId,
        tools: toolsList,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tool arrival confirmed successfully! Manager notified.'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to confirm tool arrival: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final toolsList = widget.data['tools'] as List<dynamic>? ?? [];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 22),
                SizedBox(width: 8),
                Text(
                  'Tool Arrival Confirmation',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Verify physical delivery of equipment on site and upload photo proof:',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),

            // Released Tools Items
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dispatched Equipment:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 6),
                  ...toolsList.map((t) {
                    if (t is! Map) return const SizedBox.shrink();
                    final name = (t['toolName'] ?? t['name'] ?? t['toolCode'] ?? '').toString();
                    final count = (t['toolCount'] ?? t['count'] ?? t['quantity'] ?? 1).toString();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.handyman_outlined, size: 14, color: Color(0xFF0284C7)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            '$count Units',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Upload Proof Image Section
            const Text(
              'Upload Arrival Proof Photo *',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 8),
            if (_proofImageFile == null) ...[
              InkWell(
                onTap: _showImageSourceDialog,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFCBD5E1),
                      style: BorderStyle.solid,
                      width: 1.5,
                    ),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_rounded, size: 32, color: Color(0xFF0284C7)),
                      SizedBox(height: 8),
                      Text(
                        'Tap to capture or upload delivery photo',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Delivery challan or tools at site',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      _proofImageFile!,
                      width: double.infinity,
                      height: 160,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.black.withValues(alpha: 0.6),
                          radius: 16,
                          child: IconButton(
                            icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                            onPressed: _showImageSourceDialog,
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: Colors.red.withValues(alpha: 0.8),
                          radius: 16,
                          child: IconButton(
                            icon: const Icon(Icons.delete_rounded, size: 16, color: Colors.white),
                            onPressed: () => setState(() => _proofImageFile = null),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],

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
                hintText: 'e.g. Tools received in good working condition.',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
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
                            'Confirm Tools Arrived',
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
