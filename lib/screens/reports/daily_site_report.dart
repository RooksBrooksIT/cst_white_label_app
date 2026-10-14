import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '/services/firestore_service.dart';
import '/services/expense_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '/widgets/glass_card.dart';
import '/widgets/glass_button.dart';
import '/utils/responsive.dart';
import '/utils/pdf_templates.dart';
import 'package:ebricks/utils/app_theme.dart';

class DailySiteExpensesReportPage extends StatefulWidget {
  final String supervisorId;
  final String? siteId;
  final DateTime date;
  final String? projectStage;

  const DailySiteExpensesReportPage({
    super.key,
    required this.supervisorId,
    required this.siteId,
    required this.date,
    this.projectStage,
  });

  @override
  State<DailySiteExpensesReportPage> createState() =>
      _DailySiteExpensesReportPageState();
}

class _DailySiteExpensesReportPageState
    extends State<DailySiteExpensesReportPage> {
  Future<Map<String, dynamic>> _fetchAllReports() async {
    final siteKeys = (await ExpenseService.resolveSiteKeys(widget.siteId ?? '')).toList();
    final keysToQuery = siteKeys.take(10).toList();
    final ddMMyyyy = DateFormat('ddMMyyyy').format(widget.date);
    final yyyyMMdd = DateFormat('yyyyMMdd').format(widget.date);
    final yyyy_MM_dd = DateFormat('yyyy-MM-dd').format(widget.date);
    final dd_MM_yyyy = DateFormat('dd-MM-yyyy').format(widget.date);
    final dd_slash_MM = DateFormat('dd/MM/yyyy').format(widget.date);

    // 1. Fetch Supervisor Entry
    DocumentSnapshot? filteredSupervisorDoc;
    // Try candidate document IDs
    for (final k in siteKeys) {
      final candidateIds = [
        '${k}_$ddMMyyyy',
        '${k}_$yyyyMMdd',
        '${k}_$yyyy_MM_dd',
        '${k}_$dd_MM_yyyy',
        '${k}_$dd_slash_MM',
      ];
      for (final docId in candidateIds) {
        final doc = await FirestoreService.getCollection('siteSupervisorEntries').doc(docId).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          if (data['isManagerEntry'] == true || data['createdBy'] == 'manager' ||
              data['isOrgEntry'] == true || data['createdBy'] == 'manager_org') {
            continue;
          }
          if (widget.projectStage != null) {
            final docStage = (data['projectStage'] ?? data['projectField'])?.toString().trim();
            if (docStage == widget.projectStage?.trim()) {
              filteredSupervisorDoc = doc;
              break;
            }
          } else {
            filteredSupervisorDoc = doc;
            break;
          }
        }
      }
      if (filteredSupervisorDoc != null) break;
    }

    // Fallback query by siteId / site if not found by doc ID
    if (filteredSupervisorDoc == null && keysToQuery.isNotEmpty) {
      final results = await Future.wait([
        FirestoreService.getCollection('siteSupervisorEntries').where('siteId', whereIn: keysToQuery).get(),
        FirestoreService.getCollection('siteSupervisorEntries').where('site', whereIn: keysToQuery).get(),
      ]);
      final allDocs = {...results[0].docs, ...results[1].docs};
      for (final doc in allDocs) {
        final data = doc.data();
        if (data['isManagerEntry'] == true || data['createdBy'] == 'manager' ||
            data['isOrgEntry'] == true || data['createdBy'] == 'manager_org') {
          continue;
        }
        if (ExpenseService.isSameDay(data['date'] ?? data['createdAt'], widget.date)) {
          if (widget.projectStage != null) {
            final docStage = (data['projectStage'] ?? data['projectField'])?.toString().trim();
            if (docStage == widget.projectStage?.trim()) {
              filteredSupervisorDoc = doc;
              break;
            }
          } else {
            filteredSupervisorDoc = doc;
            break;
          }
        }
      }
    }

    // 2. Fetch Manager Entries / Expenses
    final List<DocumentSnapshot> filteredManagerDocs = [];
    if (keysToQuery.isNotEmpty) {
      final results = await Future.wait([
        FirestoreService.getCollection('managerExpenses').where('siteId', whereIn: keysToQuery).get(),
        FirestoreService.getCollection('managerExpenses').where('site', whereIn: keysToQuery).get(),
        FirestoreService.getCollection('managerEntries').where('siteId', whereIn: keysToQuery).get(),
        FirestoreService.getCollection('managerEntries').where('site', whereIn: keysToQuery).get(),
      ]);
      final allMgrDocs = {...results[0].docs, ...results[1].docs, ...results[2].docs, ...results[3].docs};
      for (final doc in allMgrDocs) {
        final data = doc.data();
        if (widget.projectStage != null) {
          final docStage = (data['projectStage'] ?? data['projectField'])?.toString().trim();
          if (docStage != widget.projectStage?.trim()) continue;
        }

        // Check if bills array has items on widget.date
        final bills = data['bills'];
        if (bills is List && bills.isNotEmpty) {
          bool hasMatchingBill = false;
          for (final b in bills) {
            if (b is Map && ExpenseService.isSameDay(b['billDate'] ?? b['date'], widget.date)) {
              hasMatchingBill = true;
              break;
            }
          }
          if (hasMatchingBill) {
            filteredManagerDocs.add(doc);
            continue;
          }
        }

        // Check top-level date
        if (ExpenseService.isSameDay(data['date'] ?? data['entryDate'] ?? data['createdAt'], widget.date)) {
          filteredManagerDocs.add(doc);
        }
      }
    }

    // 3. Fetch Organization Entries / Expenses
    final List<DocumentSnapshot> filteredOrgDocs = [];
    if (keysToQuery.isNotEmpty) {
      final results = await Future.wait([
        FirestoreService.getCollection('organizationExpenses').where('siteId', whereIn: keysToQuery).get(),
        FirestoreService.getCollection('organizationExpenses').where('site', whereIn: keysToQuery).get(),
        FirestoreService.getCollection('organizationEntries').where('siteId', whereIn: keysToQuery).get(),
        FirestoreService.getCollection('organizationEntries').where('site', whereIn: keysToQuery).get(),
      ]);
      final allOrgDocs = {...results[0].docs, ...results[1].docs, ...results[2].docs, ...results[3].docs};
      for (final doc in allOrgDocs) {
        final data = doc.data();
        if (widget.projectStage != null) {
          final docStage = (data['projectStage'] ?? data['projectField'])?.toString().trim();
          if (docStage != widget.projectStage?.trim()) continue;
        }

        final bills = data['bills'];
        if (bills is List && bills.isNotEmpty) {
          bool hasMatchingBill = false;
          for (final b in bills) {
            if (b is Map && ExpenseService.isSameDay(b['billDate'] ?? b['date'], widget.date)) {
              hasMatchingBill = true;
              break;
            }
          }
          if (hasMatchingBill) {
            filteredOrgDocs.add(doc);
            continue;
          }
        }

        if (ExpenseService.isSameDay(data['date'] ?? data['entryDate'] ?? data['createdAt'], widget.date)) {
          filteredOrgDocs.add(doc);
        }
      }
    }

    // 4. Fetch Contractor Entries
    final List<DocumentSnapshot> filteredContractorDocs = [];
    if (keysToQuery.isNotEmpty) {
      final results = await Future.wait([
        FirestoreService.getCollection('contractorEntries').where('siteId', whereIn: keysToQuery).get(),
        FirestoreService.getCollection('contractorEntries').where('site', whereIn: keysToQuery).get(),
      ]);
      final allContractorDocs = {...results[0].docs, ...results[1].docs};
      for (final doc in allContractorDocs) {
        final data = doc.data();
        if (widget.projectStage != null) {
          final docStage = (data['projectStage'] ?? data['projectField'])?.toString().trim();
          if (docStage != widget.projectStage?.trim()) continue;
        }
        if (ExpenseService.isSameDay(data['date'] ?? data['createdAt'], widget.date)) {
          filteredContractorDocs.add(doc);
        }
      }
    }

    // 5. Fetch Incentive Entries
    DocumentSnapshot? filteredIncentiveDoc;
    if (keysToQuery.isNotEmpty) {
      final results = await Future.wait([
        FirestoreService.getCollection('totalSiteExpensesPerDay').where('siteId', whereIn: keysToQuery).get(),
        FirestoreService.siteSupervisorIncentives.where('siteId', whereIn: keysToQuery).get(),
      ]);
      final allIncDocs = {...results[0].docs, ...results[1].docs};
      for (final doc in allIncDocs) {
        final data = doc.data();
        if (ExpenseService.isSameDay(data['date'] ?? data['updatedAt'] ?? data['createdAt'], widget.date)) {
          if (widget.projectStage != null) {
            final docStage = (data['projectStage'] ?? data['projectField'])?.toString().trim();
            if (docStage == widget.projectStage?.trim()) {
              filteredIncentiveDoc = doc;
              break;
            }
          } else {
            filteredIncentiveDoc = doc;
            break;
          }
        }
      }
    }

    final pettyCashEntries = await ExpenseService.fetchPettyCashForSite(
      siteId: widget.siteId ?? '',
      date: widget.date,
      projectStage: widget.projectStage,
    );

    final supervisorEntryData =
        filteredSupervisorDoc?.data() as Map<String, dynamic>?;
    final siteHeader = await _resolveHeaderDetails(
      siteKeys: siteKeys,
      supervisorEntryData: supervisorEntryData,
    );

    return {
      'siteHeader': siteHeader,
      'supervisor': filteredSupervisorDoc,
      'managerEntries': filteredManagerDocs,
      'organizationEntries': filteredOrgDocs,
      'contractorEntries': filteredContractorDocs,
      'incentiveDoc': filteredIncentiveDoc,
      'pettyCashEntries': pettyCashEntries,
    };
  }

  Future<Map<String, String>> _resolveHeaderDetails({
    required List<String> siteKeys,
    Map<String, dynamic>? supervisorEntryData,
  }) async {
    String siteName = '';
    String supervisorName = '';
    String siteAddress = '';

    final rawSiteId = (widget.siteId ?? '').trim();

    // 1. Resolve canonical details via ExpenseService
    if (rawSiteId.isNotEmpty) {
      try {
        final details = await ExpenseService.resolveSiteDetails(rawSiteId);
        if (details.siteName.trim().isNotEmpty) {
          siteName = details.siteName.trim();
        } else if (details.projectName != null &&
            details.projectName!.trim().isNotEmpty) {
          siteName = details.projectName!.trim();
        }

        if (details.supervisor != null && details.supervisor!.trim().isNotEmpty) {
          supervisorName = details.supervisor!.trim();
        }

        if (details.location != null && details.location!.trim().isNotEmpty) {
          siteAddress = details.location!.trim();
        }
      } catch (e) {
        debugPrint('DailySiteReport: Error resolving SiteDetails: $e');
      }
    }

    // 2. Extract from supervisorEntryData if available
    if (supervisorEntryData != null) {
      if (siteName.isEmpty) {
        final fromEntry = (supervisorEntryData['projectName'] ??
                supervisorEntryData['siteName'] ??
                supervisorEntryData['site'])
            ?.toString()
            .trim();
        if (fromEntry != null && fromEntry.isNotEmpty) {
          siteName = fromEntry;
        }
      }

      if (supervisorName.isEmpty) {
        final fromEntry = (supervisorEntryData['supervisorName'] ??
                supervisorEntryData['userName'] ??
                supervisorEntryData['supervisor'])
            ?.toString()
            .trim();
        if (fromEntry != null && fromEntry.isNotEmpty) {
          supervisorName = fromEntry;
        }
      }

      if (siteAddress.isEmpty) {
        final fromEntry = (supervisorEntryData['siteLocation'] ??
                supervisorEntryData['location'] ??
                supervisorEntryData['address'] ??
                supervisorEntryData['siteAddress'])
            ?.toString()
            .trim();
        if (fromEntry != null && fromEntry.isNotEmpty) {
          siteAddress = fromEntry;
        }
      }
    }

    // 3. Fallback: Query 'Site' collection directly
    if (siteName.isEmpty || siteAddress.isEmpty || supervisorName.isEmpty) {
      final keysToCheck = [if (rawSiteId.isNotEmpty) rawSiteId, ...siteKeys];
      for (final key in keysToCheck) {
        if (key.isEmpty) continue;
        try {
          final doc = await FirestoreService.sites.doc(key).get();
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            if (siteName.isEmpty) {
              final n = (data['siteName'] ?? data['name'] ?? data['projectName'])
                  ?.toString()
                  .trim();
              if (n != null && n.isNotEmpty) siteName = n;
            }
            if (siteAddress.isEmpty) {
              final a = (data['address'] ??
                      data['siteAddress'] ??
                      data['location'] ??
                      data['siteLocation'])
                  ?.toString()
                  .trim();
              if (a != null && a.isNotEmpty) siteAddress = a;
            }
            if (supervisorName.isEmpty) {
              final s = (data['supervisor'] ?? data['supervisorName'])
                  ?.toString()
                  .trim();
              if (s != null && s.isNotEmpty) supervisorName = s;
            }
          }
        } catch (_) {}
        if (siteName.isNotEmpty &&
            siteAddress.isNotEmpty &&
            supervisorName.isNotEmpty) {
          break;
        }
      }
    }

    // 4. Fallback: Query 'projects' collection directly
    if (siteName.isEmpty || siteAddress.isEmpty || supervisorName.isEmpty) {
      final keysToCheck = [if (rawSiteId.isNotEmpty) rawSiteId, ...siteKeys];
      for (final key in keysToCheck) {
        if (key.isEmpty) continue;
        try {
          final doc = await FirestoreService.projects.doc(key).get();
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            if (siteName.isEmpty) {
              final n = (data['siteName'] ??
                      data['projectName'] ??
                      data['name'])
                  ?.toString()
                  .trim();
              if (n != null && n.isNotEmpty) siteName = n;
            }
            if (siteAddress.isEmpty) {
              final a = (data['location'] ??
                      data['address'] ??
                      data['siteLocation'] ??
                      data['siteAddress'])
                  ?.toString()
                  .trim();
              if (a != null && a.isNotEmpty) siteAddress = a;
            }
            if (supervisorName.isEmpty) {
              final s = (data['supervisor'] ?? data['supervisorName'])
                  ?.toString()
                  .trim();
              if (s != null && s.isNotEmpty) supervisorName = s;
            }
          }
        } catch (_) {}
        if (siteName.isNotEmpty &&
            siteAddress.isNotEmpty &&
            supervisorName.isNotEmpty) {
          break;
        }
      }
    }

    // 5. Fallback: Query 'supervisors' collection for Supervisor Name
    if (supervisorName.isEmpty) {
      final supId = widget.supervisorId.trim();
      if (supId.isNotEmpty) {
        try {
          final supDoc = await FirestoreService.supervisors.doc(supId).get();
          if (supDoc.exists && supDoc.data() != null) {
            final data = supDoc.data()!;
            final n = (data['name'] ??
                    data['supervisorName'] ??
                    data['userName'] ??
                    data['fullName'])
                ?.toString()
                .trim();
            if (n != null && n.isNotEmpty) supervisorName = n;
          }
        } catch (_) {}

        if (supervisorName.isEmpty) {
          try {
            final q = await FirestoreService.supervisors
                .where('supervisorId', isEqualTo: supId)
                .limit(1)
                .get();
            if (q.docs.isNotEmpty) {
              final data = q.docs.first.data();
              final n = (data['name'] ??
                      data['supervisorName'] ??
                      data['userName'] ??
                      data['fullName'])
                  ?.toString()
                  .trim();
              if (n != null && n.isNotEmpty) supervisorName = n;
            }
          } catch (_) {}
        }

        if (supervisorName.isEmpty &&
            !supId.contains(RegExp(r'^[0-9a-fA-F\-]{16,}'))) {
          supervisorName = supId;
        }
      }
    }

    // 6. Ensure clean fallbacks
    if (siteName.isEmpty) {
      siteName = rawSiteId.isNotEmpty ? rawSiteId : 'N/A';
    }
    if (supervisorName.isEmpty) {
      supervisorName = 'N/A';
    }
    if (siteAddress.isEmpty) {
      siteAddress = 'N/A';
    }

    return {
      'siteName': siteName,
      'supervisorName': supervisorName,
      'siteAddress': siteAddress,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);
    final dateStr = DateFormat('dd MMM yyyy').format(widget.date);

    final primaryColor = theme.primaryColor;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Daily Site Report',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
            onPressed: () => _handlePdfExport(context),
            tooltip: 'Export PDF Report',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isMobile ? double.infinity : 600,
          ),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _fetchAllReports(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeaderSkeleton(theme),
                      const SizedBox(height: 48),
                      const Center(child: CircularProgressIndicator()),
                    ],
                  ),
                );
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final data = snapshot.data!;
              final siteHeader =
                  (data['siteHeader'] as Map<String, dynamic>?) ?? {};
              final supervisorDoc = data['supervisor'] as DocumentSnapshot?;
              final managerEntries = (data['managerEntries'] as List? ?? [])
                  .cast<DocumentSnapshot>();
              final orgEntries = (data['organizationEntries'] as List? ?? [])
                  .cast<DocumentSnapshot>();
              final contractorEntries =
                  (data['contractorEntries'] as List? ?? [])
                      .cast<DocumentSnapshot>();
              final incentiveDoc = data['incentiveDoc'] as DocumentSnapshot?;
              final pettyCashEntries = (data['pettyCashEntries'] as List? ?? [])
                  .cast<Map<String, dynamic>>();

              if (supervisorDoc == null &&
                  managerEntries.isEmpty &&
                  orgEntries.isEmpty &&
                  contractorEntries.isEmpty &&
                  incentiveDoc == null &&
                  pettyCashEntries.isEmpty) {
                return SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSiteHeaderSummary(theme, siteHeader),
                      const SizedBox(height: 32),
                      _buildNoDataView(theme, dateStr),
                    ],
                  ),
                );
              }

              final supervisorData =
                  supervisorDoc?.data() as Map<String, dynamic>?;
              final totalAmount = _calculateTotal(data);

              return SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSiteHeaderSummary(theme, siteHeader),
                    const SizedBox(height: 16),
                    _buildSummaryHeader(theme, dateStr, totalAmount),
                    const SizedBox(height: 24),
                    if (supervisorData != null)
                      _buildSupervisorSection(theme, supervisorData),
                    if (managerEntries.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildBillsSection(
                        theme,
                        'Manager Expenses',
                        managerEntries,
                      ),
                    ],
                    if (orgEntries.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildBillsSection(
                        theme,
                        'Organization Expenses',
                        orgEntries,
                      ),
                    ],
                    if (contractorEntries.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildContractorSection(theme, contractorEntries),
                    ],
                    if (pettyCashEntries.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildPettyCashSection(theme, pettyCashEntries),
                    ],
                    const SizedBox(height: 40),
                    GlassButton(
                      label: 'EXPORT FULL REPORT',
                      onPressed: () => _handlePdfExport(context),
                      icon: Icons.picture_as_pdf,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNoDataView(ThemeData theme, String dateStr) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No entries found for $dateStr',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          GlassButton(
            label: 'REFRESH',
            onPressed: () => setState(() {}),
            isSecondary: true,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSkeleton(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final shimmerColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: shimmerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 70, height: 10, color: shimmerColor),
                    const SizedBox(height: 6),
                    Container(width: 140, height: 16, color: shimmerColor),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: shimmerColor, height: 1),
          ),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(width: 60, height: 9, color: shimmerColor),
                          const SizedBox(height: 4),
                          Container(width: 90, height: 13, color: shimmerColor),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(width: 60, height: 9, color: shimmerColor),
                          const SizedBox(height: 4),
                          Container(width: 100, height: 13, color: shimmerColor),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSiteHeaderSummary(
      ThemeData theme, Map<String, dynamic> siteHeader) {
    final siteName =
        (siteHeader['siteName']?.toString().trim().isNotEmpty == true)
            ? siteHeader['siteName'].toString().trim()
            : 'N/A';
    final supervisorName =
        (siteHeader['supervisorName']?.toString().trim().isNotEmpty == true)
            ? siteHeader['supervisorName'].toString().trim()
            : 'N/A';
    final siteAddress =
        (siteHeader['siteAddress']?.toString().trim().isNotEmpty == true)
            ? siteHeader['siteAddress'].toString().trim()
            : 'N/A';

    final primaryColor = theme.primaryColor;
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final labelColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Site Name
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(Icons.business_rounded, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SITE NAME',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: labelColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      siteName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: borderColor, height: 1),
          ),
          // 2. Supervisor Name & 3. Site Address (Responsive Layout)
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 420;
              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderDetailItem(
                      icon: Icons.person_rounded,
                      label: 'SUPERVISOR NAME',
                      value: supervisorName,
                      iconColor: const Color(0xFF0284C7),
                      labelColor: labelColor,
                      textColor: textColor,
                    ),
                    const SizedBox(height: 12),
                    _buildHeaderDetailItem(
                      icon: Icons.location_on_rounded,
                      label: 'SITE ADDRESS',
                      value: siteAddress,
                      iconColor: const Color(0xFFE11D48),
                      labelColor: labelColor,
                      textColor: textColor,
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildHeaderDetailItem(
                      icon: Icons.person_rounded,
                      label: 'SUPERVISOR NAME',
                      value: supervisorName,
                      iconColor: const Color(0xFF0284C7),
                      labelColor: labelColor,
                      textColor: textColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildHeaderDetailItem(
                      icon: Icons.location_on_rounded,
                      label: 'SITE ADDRESS',
                      value: siteAddress,
                      iconColor: const Color(0xFFE11D48),
                      labelColor: labelColor,
                      textColor: textColor,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderDetailItem({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    required Color labelColor,
    required Color textColor,
  }) {
    final isUnset = value == 'N/A' ||
        value == 'Not Available' ||
        value == 'Not Assigned';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: labelColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isUnset ? FontWeight.normal : FontWeight.w600,
                  fontStyle: isUnset ? FontStyle.italic : FontStyle.normal,
                  color: isUnset ? labelColor : textColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryHeader(ThemeData theme, String date, num total) {
    final cs = theme.colorScheme;
    return GlassCard(
      color: cs.primary,
      child: Column(
        children: [
          Text(
            'TOTAL DAILY EXPENDITURE',
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onPrimary.withValues(alpha: 0.7),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹ ${total.toStringAsFixed(2)}',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: cs.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: cs.onPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: cs.onPrimary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Text(
                  date,
                  style: TextStyle(
                    color: cs.onPrimary.withValues(alpha: 0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupervisorSection(ThemeData theme, Map<String, dynamic> data) {
    final labours = List<Map<String, dynamic>>.from(data['labours'] ?? []);
    final materials = List<Map<String, dynamic>>.from(data['materials'] ?? []);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SITE SUPERVISOR ENTRIES',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          if (labours.isNotEmpty) ...[
            _buildSectionTitle(theme, 'Labour'),
            ...labours.map(
              (l) => _buildDetailRow(
                l['type'],
                '${l['count']} workers',
                '₹${l['amount']}',
              ),
            ),
            const Divider(height: 24),
          ],
          if (materials.isNotEmpty) ...[
            _buildSectionTitle(theme, 'Materials'),
            ...materials.map(
              (m) => _buildDetailRow(
                m['type'],
                '${m['quantity']} units',
                '₹${m['amount']}',
              ),
            ),
            const Divider(height: 24),
          ],
          _buildSectionTitle(theme, 'Other Expenses'),
          _buildDetailRow('Food', '', '₹${data['food'] ?? 0}'),
          _buildDetailRow('Fuel', '', '₹${data['fuel'] ?? 0}'),
          _buildDetailRow('Transport', '', '₹${data['transport'] ?? 0}'),
          const Divider(height: 24),
          _buildTotalRow(theme, 'Supervisor Total', data['totalAmount'] ?? 0),
        ],
      ),
    );
  }

  Widget _buildBillsSection(
    ThemeData theme,
    String title,
    List<DocumentSnapshot> entries,
  ) {
    num total = 0;
    final List<Map<String, dynamic>> allBills = [];
    for (var doc in entries) {
      final data = doc.data() as Map<String, dynamic>;
      final bills = List<Map<String, dynamic>>.from(data['bills'] ?? []);
      for (var bill in bills) {
        allBills.add(bill);
        total += _parseAmount(bill['billAmount']);
      }
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          ...allBills.map(
            (b) => _buildDetailRow(
              b['billVendor'],
              'Bill: ${b['billNo']}',
              '₹${b['billAmount']}',
            ),
          ),
          const Divider(height: 24),
          _buildTotalRow(theme, '$title Total', total),
        ],
      ),
    );
  }

  Widget _buildContractorSection(
    ThemeData theme,
    List<DocumentSnapshot> entries,
  ) {
    num total = 0;
    for (var doc in entries) {
      total += (doc.data() as Map<String, dynamic>)['totalAmount'] ?? 0;
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONTRACTOR EXPENSES',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${entries.length} contractor entries recorded for this site.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _buildTotalRow(theme, 'Contractor Total', total),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String subtitle, String amount) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            amount,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(ThemeData theme, String label, num total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '₹ ${total.toStringAsFixed(2)}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPettyCashSection(
    ThemeData theme,
    List<Map<String, dynamic>> entries,
  ) {
    num total = 0;
    for (final e in entries) {
      total += _parseAmount(e['amount']);
    }
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PETTY CASH EXPENSES',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          ...entries.map(
            (e) => _buildDetailRow(
              (e['category'] ?? 'Petty Cash').toString(),
              (e['description'] ?? '').toString(),
              '₹${_parseAmount(e['amount']).toStringAsFixed(2)}',
            ),
          ),
          const Divider(height: 24),
          _buildTotalRow(theme, 'Petty Cash Total', total),
        ],
      ),
    );
  }

  num _calculateTotal(Map<String, dynamic> data) {
    num total = 0;
    final supervisorDoc = data['supervisor'] as DocumentSnapshot?;
    if (supervisorDoc != null) {
      total +=
          (supervisorDoc.data() as Map<String, dynamic>)['totalAmount'] ?? 0;
    }

    for (var doc
        in (data['managerEntries'] as List? ?? []).cast<DocumentSnapshot>()) {
      final bills =
          (doc.data() as Map<String, dynamic>)['bills'] as List? ?? [];
      for (var b in bills) {
        total += _parseAmount(b['billAmount']);
      }
    }

    for (var doc
        in (data['organizationEntries'] as List? ?? [])
            .cast<DocumentSnapshot>()) {
      final bills =
          (doc.data() as Map<String, dynamic>)['bills'] as List? ?? [];
      for (var b in bills) {
        total += _parseAmount(b['billAmount']);
      }
    }

    for (var doc
        in (data['contractorEntries'] as List? ?? [])
            .cast<DocumentSnapshot>()) {
      total += (doc.data() as Map<String, dynamic>)['totalAmount'] ?? 0;
    }

    if (data['incentiveDoc'] != null) {
      total +=
          (data['incentiveDoc'] as DocumentSnapshot).data()
              as Map<String, dynamic>? ??
          {}['totalIncentiveExpenses'] ??
          0;
    }

    final pettyCash = (data['pettyCashEntries'] as List? ?? []);
    for (final pc in pettyCash) {
      if (pc is Map) {
        total += _parseAmount(pc['amount']);
      }
    }

    return total;
  }

  num _parseAmount(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString().replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
  }

  Future<void> _handlePdfExport(BuildContext context) async {
    await PdfTemplates.loadFonts();
    final pdf = pw.Document();
    final pdfPrimaryColor = PdfColor.fromInt(
      Theme.of(context).primaryColor.toARGB32(),
    );
    final orgDetails = await PdfTemplates.fetchOrgDetails();
    final reportData = await _fetchAllReports();
    final totalAmount = _calculateTotal(reportData);
    final dateStr = DateFormat('dd MMM yyyy').format(widget.date);

    final supervisorDoc = reportData['supervisor'] as DocumentSnapshot?;
    final supervisorData = supervisorDoc?.data() as Map<String, dynamic>?;
    final managerEntries = (reportData['managerEntries'] as List? ?? [])
        .cast<DocumentSnapshot>();
    final orgEntries = (reportData['organizationEntries'] as List? ?? [])
        .cast<DocumentSnapshot>();
    final contractorEntries = (reportData['contractorEntries'] as List? ?? [])
        .cast<DocumentSnapshot>();
    final pettyCashEntries = (reportData['pettyCashEntries'] as List? ?? [])
        .cast<Map<String, dynamic>>();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => PdfTemplates.buildHeader(
          reportTitle: 'Daily site Summary Report',
          orgDetails: orgDetails,
          primaryColor: pdfPrimaryColor,
        ),
        build: (pw.Context context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              PdfTemplates.buildMetaBox(
                'Site ID',
                widget.siteId ?? 'N/A',
                pdfPrimaryColor,
              ),
              PdfTemplates.buildMetaBox('Date', dateStr, pdfPrimaryColor),
              PdfTemplates.buildMetaBox(
                'Total Spent',
                '₹ ${totalAmount.toStringAsFixed(2)}',
                pdfPrimaryColor,
              ),
            ],
          ),
          pw.SizedBox(height: 24),

          // Supervisor Section
          if (supervisorData != null) ...[
            pw.Text(
              'Site Supervisor Entries',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 14,
                color: pdfPrimaryColor,
                font: PdfTemplates.boldFont,
              ),
            ),
            pw.SizedBox(height: 8),
            if ((supervisorData['labours'] as List?)?.isNotEmpty ?? false) ...[
              pw.Text(
                'Labour',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                  font: PdfTemplates.boldFont,
                ),
              ),
              pw.Table.fromTextArray(
                headers: ['Type', 'Count', 'Amount'],
                data: (supervisorData['labours'] as List)
                    .map((l) => [l['type'], l['count'], '₹${l['amount']}'])
                    .toList(),
                headerDecoration: pw.BoxDecoration(color: pdfPrimaryColor),
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  font: PdfTemplates.boldFont,
                ),
                cellStyle: pw.TextStyle(font: PdfTemplates.regularFont),
              ),
              pw.SizedBox(height: 10),
            ],
            if ((supervisorData['materials'] as List?)?.isNotEmpty ??
                false) ...[
              pw.Text(
                'Materials',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                  font: PdfTemplates.boldFont,
                ),
              ),
              pw.Table.fromTextArray(
                headers: ['Type', 'Quantity', 'Amount'],
                data: (supervisorData['materials'] as List)
                    .map((m) => [m['type'], m['quantity'], '₹${m['amount']}'])
                    .toList(),
                headerDecoration: pw.BoxDecoration(color: pdfPrimaryColor),
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  font: PdfTemplates.boldFont,
                ),
                cellStyle: pw.TextStyle(font: PdfTemplates.regularFont),
              ),
              pw.SizedBox(height: 10),
            ],
            pw.Text(
              'Other Supervisor Expenses',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
                font: PdfTemplates.boldFont,
              ),
            ),
            pw.Table.fromTextArray(
              headers: ['Expense', 'Amount'],
              data: [
                ['Food', '₹${supervisorData['food'] ?? 0}'],
                ['Fuel', '₹${supervisorData['fuel'] ?? 0}'],
                ['Transport', '₹${supervisorData['transport'] ?? 0}'],
              ],
              headerDecoration: pw.BoxDecoration(color: pdfPrimaryColor),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                font: PdfTemplates.boldFont,
              ),
              cellStyle: pw.TextStyle(font: PdfTemplates.regularFont),
            ),
            pw.SizedBox(height: 20),
          ],

          // Manager Section
          if (managerEntries.isNotEmpty) ...[
            pw.Text(
              'Manager Expenses',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 14,
                color: pdfPrimaryColor,
                font: PdfTemplates.boldFont,
              ),
            ),
            pw.SizedBox(height: 8),
            ...managerEntries.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final bills = List<Map<String, dynamic>>.from(
                data['bills'] ?? [],
              );
              return pw.Table.fromTextArray(
                headers: ['Vendor', 'Bill No', 'Amount'],
                data: bills
                    .map(
                      (b) => [
                        b['billVendor'],
                        b['billNo'],
                        '₹${b['billAmount']}',
                      ],
                    )
                    .toList(),
                headerDecoration: pw.BoxDecoration(color: pdfPrimaryColor),
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  font: PdfTemplates.boldFont,
                ),
                cellStyle: pw.TextStyle(font: PdfTemplates.regularFont),
              );
            }),
            pw.SizedBox(height: 20),
          ],

          // Org Section
          if (orgEntries.isNotEmpty) ...[
            pw.Text(
              'Organization Expenses',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 14,
                color: pdfPrimaryColor,
                font: PdfTemplates.boldFont,
              ),
            ),
            pw.SizedBox(height: 8),
            ...orgEntries.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final bills = List<Map<String, dynamic>>.from(
                data['bills'] ?? [],
              );
              return pw.Table.fromTextArray(
                headers: ['Vendor', 'Bill No', 'Amount'],
                data: bills
                    .map(
                      (b) => [
                        b['billVendor'],
                        b['billNo'],
                        '₹${b['billAmount']}',
                      ],
                    )
                    .toList(),
                headerDecoration: pw.BoxDecoration(color: pdfPrimaryColor),
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  font: PdfTemplates.boldFont,
                ),
                cellStyle: pw.TextStyle(font: PdfTemplates.regularFont),
              );
            }),
            pw.SizedBox(height: 20),
          ],

          // Contractor Section
          if (contractorEntries.isNotEmpty) ...[
            pw.Text(
              'Contractor Expenses',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 14,
                color: pdfPrimaryColor,
                font: PdfTemplates.boldFont,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: ['Entry ID', 'Site', 'Amount'],
              data: contractorEntries.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                return [
                  doc.id,
                  d['site'] ?? 'N/A',
                  '₹${d['totalAmount'] ?? 0}',
                ];
              }).toList(),
              headerDecoration: pw.BoxDecoration(color: pdfPrimaryColor),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                font: PdfTemplates.boldFont,
              ),
              cellStyle: pw.TextStyle(font: PdfTemplates.regularFont),
            ),
            pw.SizedBox(height: 20),
          ],

          // Petty Cash Section
          if (pettyCashEntries.isNotEmpty) ...[
            pw.Text(
              'Petty Cash Expenses',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 14,
                color: pdfPrimaryColor,
                font: PdfTemplates.boldFont,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Category', 'Description', 'Amount'],
              data: pettyCashEntries.map((e) {
                return [
                  (e['category'] ?? 'Petty Cash').toString(),
                  (e['description'] ?? '-').toString(),
                  '₹${_parseAmount(e['amount']).toStringAsFixed(2)}',
                ];
              }).toList(),
              headerDecoration: pw.BoxDecoration(color: pdfPrimaryColor),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                font: PdfTemplates.boldFont,
              ),
              cellStyle: pw.TextStyle(font: PdfTemplates.regularFont),
            ),
          ],
        ],
        footer: (context) => PdfTemplates.buildFooter(context),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
