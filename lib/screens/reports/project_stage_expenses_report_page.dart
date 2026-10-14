import 'package:flutter/material.dart';
import '/services/firestore_service.dart';
import 'package:ebricks/services/expense_service.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import '/widgets/glass_card.dart';
import '/utils/responsive.dart';
import '/utils/project_stage_pdf_helper.dart';
import 'package:ebricks/screens/reports/pdf_preview_page.dart';
import 'package:ebricks/utils/app_theme.dart';

class ProjectStageExpensesReportPage extends StatefulWidget {
  final String siteId;
  final String projectStage;
  final DateTime fromDate;
  final DateTime toDate;
  final String? supervisorId;

  const ProjectStageExpensesReportPage({
    super.key,
    required this.siteId,
    required this.projectStage,
    required this.fromDate,
    required this.toDate,
    this.supervisorId,
  });

  @override
  State<ProjectStageExpensesReportPage> createState() =>
      _ProjectStageExpensesReportPageState();
}

class _ProjectStageExpensesReportPageState
    extends State<ProjectStageExpensesReportPage> {
  Map<String, String> siteHeader = {};
  double supervisorTotal = 0;
  double materialsTotal = 0;
  double labourTotal = 0;
  double managerTotal = 0;
  double organizationTotal = 0;
  double foodTotal = 0;
  double transportTotal = 0;
  double fuelTotal = 0;
  double pettyCashTotal = 0;
  double contractorTotal = 0;
  double incentiveTotal = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => isLoading = true);

    try {
      final siteKeys =
          (await ExpenseService.resolveSiteKeys(widget.siteId)).toList();
      final keysToQuery = siteKeys.take(10).toList();

      final results = await Future.wait([
        // 0, 1: Supervisor entries
        FirestoreService.getCollection('siteSupervisorEntries').where('siteId', whereIn: keysToQuery).get(),
        FirestoreService.getCollection('siteSupervisorEntries').where('site', whereIn: keysToQuery).get(),
        // 2, 3: Manager expenses & entries
        FirestoreService.getCollection('managerExpenses').where('siteId', whereIn: keysToQuery).get(),
        FirestoreService.getCollection('managerEntries').where('siteId', whereIn: keysToQuery).get(),
        // 4, 5: Organization entries & expenses
        FirestoreService.getCollection('organizationEntries').where('siteId', whereIn: keysToQuery).get(),
        FirestoreService.getCollection('organizationExpenses').where('siteId', whereIn: keysToQuery).get(),
        // 6: Contractor entries
        FirestoreService.getCollection('contractorEntries').where('siteId', whereIn: keysToQuery).get(),
        // 7: Incentives
        FirestoreService.siteSupervisorIncentives.where('siteId', whereIn: keysToQuery).get(),
      ]);

      final pettyCashEntries = await ExpenseService.fetchPettyCashForSite(
        siteId: widget.siteId,
        fromDate: widget.fromDate,
        toDate: widget.toDate,
        projectStage: widget.projectStage,
      );

      final allSupDocs = {...results[0].docs, ...results[1].docs};
      final allMgrDocs = {...results[2].docs, ...results[3].docs};
      final allOrgDocs = {...results[4].docs, ...results[5].docs};
      final allContractorDocs = results[6].docs;
      final allIncentiveDocs = results[7].docs;

      final targetStage = widget.projectStage.trim().toLowerCase();

      double sTotal = 0;
      double matTotal = 0;
      double labTotal = 0;
      double mTotal = 0;
      double oTotal = 0;
      double fTotal = 0;
      double tTotal = 0;
      double flTotal = 0;
      double pcTotal = 0;
      double cTotal = 0;
      double incTotal = 0;

      // 1. Process Supervisor entries
      for (final doc in allSupDocs) {
        final data = doc.data();
        if (data['isManagerEntry'] == true || data['createdBy'] == 'manager' ||
            data['isOrgEntry'] == true || data['createdBy'] == 'manager_org') {
          continue;
        }
        final docStage = (data['projectStage'] ?? data['projectField'] ?? data['stage'])
            ?.toString()
            .trim()
            .toLowerCase();
        if (targetStage.isNotEmpty && docStage != null && docStage != targetStage) {
          continue;
        }

        final entryDate = ExpenseService.parseDate(
          data['date'] ?? data['entryDate'] ?? data['createdAt'],
        );
        if (entryDate == null || !ExpenseService.isDateInRange(entryDate, widget.fromDate, widget.toDate)) {
          continue;
        }

        sTotal += _toDouble(data['totalAmount'] ?? data['amount']);
        fTotal += _toDouble(data['food']);
        tTotal += _toDouble(data['transport']);
        flTotal += _toDouble(data['fuel']);

        final materials = data['materials'];
        if (materials is List) {
          for (final m in materials) {
            if (m is Map) {
              final amt = _toDouble(m['amount']);
              if (amt > 0) {
                matTotal += amt;
              } else {
                final qty = _toDouble(m['quantity'] ?? m['qty']);
                final price = _toDouble(m['unitPrice'] ?? m['price']);
                matTotal += (qty * price);
              }
            }
          }
        }

        final labours = data['labours'];
        if (labours is List) {
          for (final l in labours) {
            if (l is Map) {
              final amt = _toDouble(l['amount']);
              if (amt > 0) {
                labTotal += amt;
              } else {
                final count = _toDouble(l['count']);
                final salary = _toDouble(l['unitSalary'] ?? l['salary']);
                labTotal += (count * salary);
              }
            }
          }
        }
      }

      // 2. Process Manager entries
      for (final doc in allMgrDocs) {
        final data = doc.data();
        final docStage = (data['projectStage'] ?? data['projectField'] ?? data['stage'])
            ?.toString()
            .trim()
            .toLowerCase();
        if (targetStage.isNotEmpty && docStage != null && docStage != targetStage) {
          continue;
        }

        final bills = data['bills'];
        if (bills is List && bills.isNotEmpty) {
          for (final bill in bills) {
            if (bill is Map) {
              final billDate = ExpenseService.parseDate(bill['billDate'] ?? bill['date']);
              if (billDate != null && ExpenseService.isDateInRange(billDate, widget.fromDate, widget.toDate)) {
                mTotal += _toDouble(bill['billAmount'] ?? bill['amount'] ?? bill['totalAmount']);
              }
            }
          }
        } else {
          final entryDate = ExpenseService.parseDate(
            data['entryDate'] ?? data['date'] ?? data['createdAt'],
          );
          if (entryDate != null && ExpenseService.isDateInRange(entryDate, widget.fromDate, widget.toDate)) {
            mTotal += _toDouble(data['totalAmount'] ?? data['amount']);
          }
        }
      }

      // 3. Process Organization entries
      for (final doc in allOrgDocs) {
        final data = doc.data();
        final docStage = (data['projectStage'] ?? data['projectField'] ?? data['stage'])
            ?.toString()
            .trim()
            .toLowerCase();
        if (targetStage.isNotEmpty && docStage != null && docStage != targetStage) {
          continue;
        }

        final bills = data['bills'];
        if (bills is List && bills.isNotEmpty) {
          for (final bill in bills) {
            if (bill is Map) {
              final billDate = ExpenseService.parseDate(bill['billDate'] ?? bill['date']);
              if (billDate != null && ExpenseService.isDateInRange(billDate, widget.fromDate, widget.toDate)) {
                oTotal += _toDouble(bill['billAmount'] ?? bill['amount'] ?? bill['totalAmount']);
              }
            }
          }
        } else {
          final entryDate = ExpenseService.parseDate(
            data['entryDate'] ?? data['date'] ?? data['createdAt'],
          );
          if (entryDate != null && ExpenseService.isDateInRange(entryDate, widget.fromDate, widget.toDate)) {
            oTotal += _toDouble(data['totalAmount'] ?? data['amount']);
          }
        }
      }

      // 4. Process Contractor entries
      for (final doc in allContractorDocs) {
        final data = doc.data();
        final docStage = (data['projectStage'] ?? data['projectField'] ?? data['workStage'])
            ?.toString()
            .trim()
            .toLowerCase();
        if (targetStage.isNotEmpty && docStage != null && docStage != targetStage) {
          continue;
        }

        final entryDate = ExpenseService.parseDate(data['date'] ?? data['createdAt']);
        if (entryDate == null || !ExpenseService.isDateInRange(entryDate, widget.fromDate, widget.toDate)) {
          continue;
        }

        cTotal += _toDouble(data['totalAmount'] ?? data['amount']);
        fTotal += _toDouble(data['food']);
        tTotal += _toDouble(data['transport']);
        flTotal += _toDouble(data['fuel']);

        final materials = data['materials'];
        if (materials is List) {
          for (final m in materials) {
            if (m is Map) {
              final amt = _toDouble(m['amount']);
              if (amt > 0) {
                matTotal += amt;
              } else {
                final qty = _toDouble(m['quantity'] ?? m['qty']);
                final price = _toDouble(m['unitPrice'] ?? m['price']);
                matTotal += (qty * price);
              }
            }
          }
        }

        final labours = data['labours'];
        if (labours is List) {
          for (final l in labours) {
            if (l is Map) {
              final amt = _toDouble(l['amount']);
              if (amt > 0) {
                labTotal += amt;
              } else {
                final count = _toDouble(l['count']);
                final salary = _toDouble(l['unitSalary'] ?? l['salary']);
                labTotal += (count * salary);
              }
            }
          }
        }
      }

      // 5. Process Incentives
      for (final doc in allIncentiveDocs) {
        final data = doc.data();
        final entryDate = ExpenseService.parseDate(
          data['updatedAt'] ?? data['createdAt'] ?? data['date'],
        );
        if (entryDate != null && ExpenseService.isDateInRange(entryDate, widget.fromDate, widget.toDate)) {
          incTotal += _toDouble(data['incentiveAmount'] ?? data['amount']);
        }
      }

      // 6. Process Petty Cash
      for (final pc in pettyCashEntries) {
        pcTotal += _toDouble(pc['amount']);
      }

      // Find candidate supervisor entry for metadata if available
      Map<String, dynamic>? supervisorEntryData;
      for (final doc in allSupDocs) {
        final data = doc.data();
        if (data['isManagerEntry'] == true || data['createdBy'] == 'manager' ||
            data['isOrgEntry'] == true || data['createdBy'] == 'manager_org') {
          continue;
        }
        final docStage = (data['projectStage'] ?? data['projectField'] ?? data['stage'])
            ?.toString()
            .trim()
            .toLowerCase();
        if (targetStage.isNotEmpty && docStage != null && docStage != targetStage) {
          continue;
        }
        supervisorEntryData = data;
        break;
      }
      if (supervisorEntryData == null) {
        for (final doc in allSupDocs) {
          final data = doc.data();
          if (data['isManagerEntry'] == true || data['createdBy'] == 'manager' ||
              data['isOrgEntry'] == true || data['createdBy'] == 'manager_org') {
            continue;
          }
          supervisorEntryData = data;
          break;
        }
      }

      final resolvedHeader = await _resolveHeaderDetails(
        siteKeys: siteKeys,
        supervisorEntryData: supervisorEntryData,
      );

      if (mounted) {
        setState(() {
          siteHeader = resolvedHeader;
          supervisorTotal = sTotal;
          materialsTotal = matTotal;
          labourTotal = labTotal;
          managerTotal = mTotal;
          organizationTotal = oTotal;
          foodTotal = fTotal;
          transportTotal = tTotal;
          fuelTotal = flTotal;
          pettyCashTotal = pcTotal;
          contractorTotal = cTotal;
          incentiveTotal = incTotal;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading stage expenses report: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);

    final primaryColor = theme.primaryColor;
    final darkAccent = AppTheme.getDarkAccent(primaryColor);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Stage Expense Analysis',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
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
            tooltip: 'Export PDF',
            onPressed: isLoading ? null : _generatePdf,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isMobile ? double.infinity : 600,
          ),
          child: isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSiteHeaderSummary(theme, siteHeader),
                      _buildHeader(theme),
                      const SizedBox(height: 24),
                      _buildFinanceSummary(theme),
                      const SizedBox(height: 24),
                      _buildBreakdownSection(theme),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.layers_outlined, color: theme.primaryColor),
              const SizedBox(width: 12),
              Text(
                widget.projectStage,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Period: ${DateFormat('dd MMM').format(widget.fromDate)} - ${DateFormat('dd MMM yyyy').format(widget.toDate)}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceSummary(ThemeData theme) {
    final grandTotal =
        supervisorTotal +
        managerTotal +
        organizationTotal +
        contractorTotal +
        incentiveTotal +
        pettyCashTotal;
    return GlassCard(
      color: theme.primaryColor,
      child: Column(
        children: [
          const Text(
            'TOTAL EXPENDITURE',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹ ${grandTotal.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'EXPENSE BREAKDOWN',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        _expenseItem(
          'Site Supervisor Expenses',
          supervisorTotal,
          Icons.engineering_outlined,
          theme,
        ),
        _expenseItem(
          'Materials',
          materialsTotal,
          Icons.inventory_2_outlined,
          theme,
        ),
        _expenseItem(
          'Labour',
          labourTotal,
          Icons.handyman_outlined,
          theme,
        ),
        _expenseItem(
          'Manager Expenses',
          managerTotal,
          Icons.manage_accounts_outlined,
          theme,
        ),
        _expenseItem(
          'Organization Expenses',
          organizationTotal,
          Icons.business_outlined,
          theme,
        ),
        _expenseItem(
          'Food',
          foodTotal,
          Icons.restaurant_outlined,
          theme,
        ),
        _expenseItem(
          'Transport',
          transportTotal,
          Icons.local_shipping_outlined,
          theme,
        ),
        _expenseItem(
          'Fuel',
          fuelTotal,
          Icons.local_gas_station_outlined,
          theme,
        ),
        _expenseItem(
          'Petty Cash',
          pettyCashTotal,
          Icons.payments_outlined,
          theme,
        ),
        if (contractorTotal > 0)
          _expenseItem(
            'Contractor Expenses',
            contractorTotal,
            Icons.construction_outlined,
            theme,
          ),
        if (incentiveTotal > 0)
          _expenseItem(
            'Incentives',
            incentiveTotal,
            Icons.emoji_events_outlined,
            theme,
          ),
      ],
    );
  }

  Widget _expenseItem(
    String label,
    double amount,
    IconData icon,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: theme.primaryColor, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              '₹ ${amount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generatePdf() async {
    final pdfPrimaryColor = PdfColor.fromInt(
      Theme.of(context).primaryColor.toARGB32(),
    );
    try {
      final pdfBytes = await ProjectStagePdfHelper.buildExpenseRangeReport(
        siteId: widget.siteId,
        projectStage: widget.projectStage,
        fromDate: widget.fromDate,
        toDate: widget.toDate,
        supervisorTotal: supervisorTotal,
        managerTotal: managerTotal,
        organizationTotal: organizationTotal,
        contractorTotal: contractorTotal,
        incentiveTotal: incentiveTotal,
        materialsTotal: materialsTotal,
        labourTotal: labourTotal,
        foodTotal: foodTotal,
        transportTotal: transportTotal,
        fuelTotal: fuelTotal,
        pettyCashTotal: pettyCashTotal,
        primaryColor: pdfPrimaryColor,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfPreviewPage(
            pdfBytes: pdfBytes,
            fileName:
                'ExpenseRange_${widget.siteId}_${DateFormat('ddMMyyyy').format(widget.fromDate)}_${DateFormat('ddMMyyyy').format(widget.toDate)}.pdf',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to generate PDF: $e')));
    }
  }

  Future<Map<String, String>> _resolveHeaderDetails({
    required List<String> siteKeys,
    Map<String, dynamic>? supervisorEntryData,
  }) async {
    String siteName = '';
    String supervisorName = '';
    String siteAddress = '';

    final rawSiteId = widget.siteId.trim();

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
        debugPrint('ProjectStageExpensesReportPage: Error resolving SiteDetails: $e');
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
      final supId = (widget.supervisorId ??
              supervisorEntryData?['supervisorId'] ??
              supervisorEntryData?['userId'] ??
              '').trim();
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
}
