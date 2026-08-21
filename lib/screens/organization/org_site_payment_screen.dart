import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/utils/app_theme.dart';

class SitePaymentScreen extends StatefulWidget {
  const SitePaymentScreen({super.key});

  @override
  SitePaymentScreenState createState() => SitePaymentScreenState();
}

class SitePaymentScreenState extends State<SitePaymentScreen> {
  // Site list for dropdown (list of {id, display})
  List<Map<String, String>> siteList = [];

  String? selectedSiteId;
  String supervisor = '';
  int amount = 0;
  DateTime? selectedDate;
  final TextEditingController amountController = TextEditingController();
  final TextEditingController supervisorController = TextEditingController();

  // Project Stage Dropdown
  List<String> projectStages = [];
  String? selectedProjectStage;

  // Payment Period
  int selectedPaymentYear = DateTime.now().year;
  int selectedPaymentMonth = DateTime.now().month;
  int? selectedPaymentWeekIndex;

  List<int> paymentYears = List.generate(
    5,
    (index) => DateTime.now().year - 2 + index,
  );

  List<List<DateTime>> _getWeeksOfMonth(int year, int month) {
    List<List<DateTime>> weeks = [];
    try {
      DateTime firstDay = DateTime(year, month, 1);
      DateTime lastDayOfMonth = month == 12
          ? DateTime(year + 1, 1, 1).subtract(const Duration(days: 1))
          : DateTime(year, month + 1, 1).subtract(const Duration(days: 1));

      int dayOffset = firstDay.weekday - 1; // 0 for Monday
      DateTime weekStart = firstDay.subtract(Duration(days: dayOffset));

      while (weekStart.isBefore(lastDayOfMonth) ||
          weekStart.isAtSameMomentAs(lastDayOfMonth)) {
        List<DateTime> week = [];

        for (int i = 0; i < 7; i++) {
          DateTime day = weekStart.add(Duration(days: i));
          if (day.month == month && day.year == year) {
            week.add(day);
          }
        }

        if (week.isNotEmpty) {
          weeks.add(week);
        }

        weekStart = weekStart.add(const Duration(days: 7));

        if (weekStart.month > month || (weekStart.month == 1 && month == 12)) {
          break;
        }
      }
    } catch (e) {
      debugPrint('Error calculating weeks of month: $e');
      weeks = [];
    }
    return weeks;
  }

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    _fetchSiteIds();
    _fetchProjectStages();
  }

  @override
  void dispose() {
    amountController.dispose();
    supervisorController.dispose();
    super.dispose();
  }

  Future<void> _fetchProjectStages() async {
    try {
      final snapshot = await FirestoreService.projectStages.get().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
            'Project stages query timeout',
            const Duration(seconds: 10),
          );
        },
      );

      if (!mounted) return;

      setState(() {
        projectStages = snapshot.docs
            .map((doc) => (doc.data()['projectStage'] ?? '').toString())
            .where((stage) => stage.isNotEmpty)
            .toList();
      });
    } on TimeoutException catch (e) {
      debugPrint('Timeout fetching project stages: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load project stages')),
        );
      }
    } catch (e) {
      debugPrint('Error fetching project stages: $e');
    }
  }

  Future<void> _fetchSiteIds() async {
    try {
      final snapshot = await FirestoreService.getCollection('Site')
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException(
                'Site IDs query timeout',
                const Duration(seconds: 10),
              );
            },
          );

      if (!mounted) return;

      setState(() {
        siteList = snapshot.docs.map<Map<String, String>>((doc) {
          final data = doc.data();
          final display = (data['siteName'] ?? doc.id).toString();
          return {
            'id': doc.id,
            'display': '${doc.id} - $display',
          };
        }).toList();
      });
    } on TimeoutException catch (e) {
      debugPrint('Timeout fetching site IDs: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load sites')),
        );
      }
    } catch (e) {
      debugPrint('Error fetching site IDs: $e');
    }
  }

  Future<void> _fetchSupervisorForSite(String siteId) async {
    try {
      // 1. Check Site collection doc
      String siteName = '';
      final siteDoc = await FirestoreService.getCollection('Site')
          .doc(siteId)
          .get();

      if (siteDoc.exists && siteDoc.data() != null) {
        final siteData = siteDoc.data()!;
        final supervisorValue = siteData['Supervisor'] ??
            siteData['supervisor'] ??
            siteData['supervisorName'] ??
            siteData['supervisor_name'];

        if (supervisorValue != null &&
            supervisorValue.toString().trim().isNotEmpty) {
          final foundName = supervisorValue.toString().trim();
          if (mounted) {
            setState(() {
              supervisor = foundName;
              supervisorController.text = foundName;
            });
          }
          return;
        }

        siteName = (siteData['siteName'] ?? siteData['site'] ?? '')
            .toString()
            .trim();
      }

      // 2. Check siteSupervisorMap by docId matching siteId
      final mapDoc =
          await FirestoreService.siteSupervisorMap.doc(siteId).get();
      if (mapDoc.exists && mapDoc.data() != null) {
        final mapData = mapDoc.data()!;
        final sup = mapData['supervisor'] ??
            mapData['supervisorName'] ??
            mapData['Supervisor'] ??
            mapData['supervisor_name'] ??
            mapData['name'];
        if (sup != null && sup.toString().trim().isNotEmpty) {
          final foundName = sup.toString().trim();
          if (mounted) {
            setState(() {
              supervisor = foundName;
              supervisorController.text = foundName;
            });
          }
          return;
        }
      }

      // 3. Query siteSupervisorMap by site / siteId / siteName fields
      final queriesToTry = [
        FirestoreService.siteSupervisorMap.where('site', isEqualTo: siteId),
        FirestoreService.siteSupervisorMap.where('siteId', isEqualTo: siteId),
        FirestoreService.siteSupervisorMap.where('siteName', isEqualTo: siteId),
      ];

      if (siteName.isNotEmpty) {
        queriesToTry.add(
          FirestoreService.siteSupervisorMap.where('site', isEqualTo: siteName),
        );
        queriesToTry.add(
          FirestoreService.siteSupervisorMap.where(
            'siteName',
            isEqualTo: siteName,
          ),
        );
        queriesToTry.add(
          FirestoreService.siteSupervisorMap.where(
            'siteId',
            isEqualTo: siteName,
          ),
        );
      }

      for (var query in queriesToTry) {
        final snapshot = await query.get();
        if (snapshot.docs.isNotEmpty) {
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final sup = data['supervisor'] ??
                data['supervisorName'] ??
                data['Supervisor'] ??
                data['supervisor_name'] ??
                data['name'];
            if (sup != null && sup.toString().trim().isNotEmpty) {
              final foundName = sup.toString().trim();
              if (mounted) {
                setState(() {
                  supervisor = foundName;
                  supervisorController.text = foundName;
                });
              }
              return;
            }
          }
        }
      }

      // 4. Comprehensive Fallback: Fetch all siteSupervisorMap entries and match flexibly
      final allMapDocs = await FirestoreService.siteSupervisorMap.get();
      final targetSiteIdLower = siteId.toLowerCase().trim();
      final targetSiteNameLower = siteName.toLowerCase().trim();

      for (var doc in allMapDocs.docs) {
        final data = doc.data();
        final docSite =
            (data['site'] ?? '').toString().toLowerCase().trim();
        final docSiteName =
            (data['siteName'] ?? '').toString().toLowerCase().trim();
        final docSiteId =
            (data['siteId'] ?? '').toString().toLowerCase().trim();
        final docId = doc.id.toLowerCase().trim();

        final isMatch = (docSite.isNotEmpty &&
                (docSite == targetSiteIdLower ||
                    (targetSiteNameLower.isNotEmpty &&
                        docSite == targetSiteNameLower))) ||
            (docSiteName.isNotEmpty &&
                (docSiteName == targetSiteIdLower ||
                    (targetSiteNameLower.isNotEmpty &&
                        docSiteName == targetSiteNameLower))) ||
            (docSiteId.isNotEmpty &&
                (docSiteId == targetSiteIdLower ||
                    (targetSiteNameLower.isNotEmpty &&
                        docSiteId == targetSiteNameLower))) ||
            (docId == targetSiteIdLower ||
                (targetSiteNameLower.isNotEmpty &&
                    docId == targetSiteNameLower));

        if (isMatch) {
          final sup = data['supervisor'] ??
              data['supervisorName'] ??
              data['Supervisor'] ??
              data['supervisor_name'] ??
              data['name'];
          if (sup != null && sup.toString().trim().isNotEmpty) {
            final foundName = sup.toString().trim();
            if (mounted) {
              setState(() {
                supervisor = foundName;
                supervisorController.text = foundName;
              });
            }
            return;
          }
        }
      }

      // 5. If still not found, check 'sites' collection
      final sitesDoc = await FirestoreService.getCollection('sites')
          .doc(siteId)
          .get();
      if (sitesDoc.exists && sitesDoc.data() != null) {
        final data = sitesDoc.data()!;
        final sup = data['Supervisor'] ??
            data['supervisor'] ??
            data['supervisorName'] ??
            data['supervisor_name'];
        if (sup != null && sup.toString().trim().isNotEmpty) {
          final foundName = sup.toString().trim();
          if (mounted) {
            setState(() {
              supervisor = foundName;
              supervisorController.text = foundName;
            });
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          supervisor = 'No Supervisor Assigned';
          supervisorController.text = 'No Supervisor Assigned';
        });
      }
    } catch (e) {
      debugPrint('Error fetching supervisor for site: $e');
      if (mounted) {
        setState(() {
          supervisor = 'Error Loading Supervisor';
          supervisorController.text = 'Error Loading Supervisor';
        });
      }
    }
  }

  void resetForm() {
    setState(() {
      selectedSiteId = null;
      supervisor = '';
      supervisorController.clear();
      amount = 0;
      amountController.clear();
      selectedProjectStage = null;
      selectedPaymentYear = DateTime.now().year;
      selectedPaymentMonth = DateTime.now().month;
      selectedPaymentWeekIndex = null;
      selectedDate = DateTime.now();
    });
  }

  Future<void> _submitPayment() async {
    if (selectedSiteId == null || selectedSiteId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a Site ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (selectedPaymentWeekIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a Payment Week'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a Payment Date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final paymentData = {
        'siteId': selectedSiteId,
        'supervisor': supervisor,
        'amount': amount,
        'projectStage': selectedProjectStage ?? '',
        'paymentYear': selectedPaymentYear,
        'paymentMonth': selectedPaymentMonth,
        'paymentWeekIndex': selectedPaymentWeekIndex! + 1,
        'paymentDate': Timestamp.fromDate(selectedDate!),
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirestoreService.getCollection(
        'siteSupervisorPayments',
      ).add(paymentData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                SizedBox(width: 10),
                Text('Payment Recorded Successfully!'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      resetForm();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding payment: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Color get primaryColor => Theme.of(context).colorScheme.primary;

  @override
  Widget build(BuildContext context) {
    final darkAccent = AppTheme.getDarkAccent(primaryColor);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Site Payment Entry',
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
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 850.0 : (isTablet ? 680.0 : double.infinity),
            ),
            child: _buildBody(context, isDesktop, isTablet, isMobile),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 28.0 : 16.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, isDesktop, isTablet, isMobile),
          const SizedBox(height: 20),
          _buildForm(context, isDesktop, isTablet, isMobile),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 20.0 : 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A183D).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.payments_rounded,
              color: primaryColor,
              size: isDesktop ? 30.0 : 26.0,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Payment Entry',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0A183D),
                    fontSize: 18.0,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Record site supervisor payment disbursements & details',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selectedSiteId != null && amount > 0)
          _buildSummaryCard(context, isDesktop),
        
        // SECTION 1: SITE & SUPERVISOR DETAILS
        _buildSectionHeader(
          title: '1. Site & Supervisor Details',
          subtitle: 'Select project site and supervisor',
          icon: Icons.location_on_rounded,
          color: primaryColor,
        ),
        const SizedBox(height: 16),
        _buildSiteDropdown(context, isDesktop, isTablet, isMobile),
        const SizedBox(height: 14),
        _buildSupervisorField(context),
        const SizedBox(height: 24),
        const Divider(color: Color(0xFFE2E8F0)),
        const SizedBox(height: 16),

        // SECTION 2: PAYMENT AMOUNT & STAGE
        _buildSectionHeader(
          title: '2. Payment Amount & Stage',
          subtitle: 'Enter payment value & project stage milestone',
          icon: Icons.monetization_on_rounded,
          color: const Color(0xFF10B981),
        ),
        const SizedBox(height: 16),
        _buildAmountField(context),
        const SizedBox(height: 14),
        _buildProjectStageDropdown(context, isDesktop, isTablet, isMobile),
        const SizedBox(height: 24),
        const Divider(color: Color(0xFFE2E8F0)),
        const SizedBox(height: 16),

        // SECTION 3: PAYMENT PERIOD & DATE
        _buildSectionHeader(
          title: '3. Payment Period & Dates',
          subtitle: 'Select payment period year, month & week',
          icon: Icons.calendar_month_rounded,
          color: Colors.indigo,
        ),
        const SizedBox(height: 16),
        _buildPeriodSelection(context, isDesktop, isTablet, isMobile),
        const SizedBox(height: 20),
        _buildWeeksSelection(context, isDesktop, isTablet, isMobile),
        if (selectedPaymentWeekIndex != null) ...[
          const SizedBox(height: 20),
          _buildDatePickerSection(context, isDesktop, isTablet, isMobile),
        ],

        const SizedBox(height: 28),
        _buildActionButtons(context, isDesktop, isTablet, isMobile),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A183D),
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context, bool isDesktop) {
    final formattedAmount = NumberFormat.currency(
      symbol: '₹',
      decimalDigits: 0,
      locale: 'en_IN',
    ).format(amount);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 20.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: primaryColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment Summary',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${supervisor.isEmpty ? "Supervisor" : supervisor} • ${selectedSiteId ?? ""}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0A183D),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            formattedAmount,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteDropdown(
    BuildContext context,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    return _buildDropdownContainer(
      context,
      label: 'Site ID *',
      isDesktop: isDesktop,
      isTablet: isTablet,
      isMobile: isMobile,
      child: DropdownButtonFormField<String>(
        initialValue: selectedSiteId,
        isExpanded: true,
        dropdownColor: Colors.white,
        style: const TextStyle(
          color: Color(0xFF0A183D),
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: 'Select Site ID',
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 12.5,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            Icons.place_rounded,
            color: primaryColor,
            size: 20.0,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        items: siteList.map((site) {
          return DropdownMenuItem<String>(
            value: site['id'],
            child: Text(
              site['display'] ?? '',
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF0A183D),
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
        onChanged: (value) async {
          setState(() {
            selectedSiteId = value;
            supervisor = '';
            supervisorController.clear();
            amount = 0;
            amountController.text = '';
          });
          if (value != null) {
            await _fetchSupervisorForSite(value);
          }
        },
      ),
    );
  }

  Widget _buildSupervisorField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Supervisor',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: supervisorController,
          readOnly: true,
          style: const TextStyle(
            color: Color(0xFF0A183D),
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.person_rounded,
              color: primaryColor,
              size: 20.0,
            ),
            hintText: 'Auto-fetched supervisor name',
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12.5,
            ),
            filled: true,
            fillColor: Colors.grey.shade100,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Amount (₹) *',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: amountController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            color: Color(0xFF0A183D),
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.currency_rupee_rounded,
              color: primaryColor,
              size: 20.0,
            ),
            hintText: 'Enter payment amount',
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor, width: 1.8),
            ),
          ),
          onChanged: (value) {
            setState(() {
              amount = int.tryParse(value) ?? 0;
            });
          },
        ),
      ],
    );
  }

  Widget _buildProjectStageDropdown(
    BuildContext context,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    return _buildDropdownContainer(
      context,
      label: 'Project Stage',
      isDesktop: isDesktop,
      isTablet: isTablet,
      isMobile: isMobile,
      child: DropdownButtonFormField<String>(
        initialValue: selectedProjectStage,
        isExpanded: true,
        dropdownColor: Colors.white,
        style: const TextStyle(
          color: Color(0xFF0A183D),
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: 'Select Project Stage',
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 12.5,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            Icons.flag_rounded,
            color: primaryColor,
            size: 20.0,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        items: projectStages.map((stage) {
          return DropdownMenuItem<String>(
            value: stage,
            child: Text(
              stage,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF0A183D),
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            selectedProjectStage = value;
          });
        },
      ),
    );
  }

  Widget _buildPeriodSelection(
    BuildContext context,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    final yearWidget = _buildDropdownContainer(
      context,
      label: 'Year *',
      isDesktop: isDesktop,
      isTablet: isTablet,
      isMobile: isMobile,
      child: DropdownButtonFormField<int>(
        initialValue: selectedPaymentYear,
        isExpanded: true,
        dropdownColor: Colors.white,
        style: const TextStyle(
          color: Color(0xFF0A183D),
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(
            Icons.calendar_today_rounded,
            color: primaryColor,
            size: 20.0,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        items: paymentYears.map((y) {
          return DropdownMenuItem<int>(
            value: y,
            child: Text(
              y.toString(),
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF0A183D),
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            selectedPaymentYear = value!;
            selectedPaymentWeekIndex = null;
          });
        },
      ),
    );

    final monthWidget = _buildDropdownContainer(
      context,
      label: 'Month *',
      isDesktop: isDesktop,
      isTablet: isTablet,
      isMobile: isMobile,
      child: DropdownButtonFormField<int>(
        initialValue: selectedPaymentMonth,
        isExpanded: true,
        dropdownColor: Colors.white,
        style: const TextStyle(
          color: Color(0xFF0A183D),
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(
            Icons.calendar_month_rounded,
            color: primaryColor,
            size: 20.0,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        items: List.generate(12, (i) => i + 1).map((m) {
          return DropdownMenuItem<int>(
            value: m,
            child: Text(
              DateFormat.MMMM().format(DateTime(0, m)),
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF0A183D),
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            selectedPaymentMonth = value!;
            selectedPaymentWeekIndex = null;
          });
        },
      ),
    );

    return Row(
      children: [
        Expanded(child: yearWidget),
        const SizedBox(width: 12),
        Expanded(child: monthWidget),
      ],
    );
  }

  Widget _buildDropdownContainer(
    BuildContext context, {
    required String label,
    required Widget child,
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _submitPayment,
              icon: const Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: Colors.white,
              ),
              label: const Text(
                'Submit Payment',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 15.0,
                  letterSpacing: 0.3,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 3,
                shadowColor: primaryColor.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.0),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: resetForm,
              icon: const Icon(
                Icons.restart_alt_rounded,
                size: 18,
                color: Color(0xFF64748B),
              ),
              label: const Text(
                'Reset',
                style: TextStyle(
                  fontSize: 15.0,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A183D),
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0A183D),
                side: const BorderSide(
                  color: Color(0xFFCBD5E1),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.0),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeeksSelection(
    BuildContext context,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    final weeks = _getWeeksOfMonth(selectedPaymentYear, selectedPaymentMonth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Week *',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 8),
        weeks.isEmpty
            ? Container(
                padding: const EdgeInsets.all(16.0),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Text(
                  'No weeks available for selected month',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13.0,
                  ),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final double spacing = 10.0;
                  final double width = (constraints.maxWidth - spacing) / 2;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: List.generate(weeks.length, (i) {
                      final week = weeks[i];
                      final startDate = DateFormat('MMM dd').format(week.first);
                      final endDate = DateFormat('MMM dd').format(week.last);
                      final isSelected = selectedPaymentWeekIndex == i;

                      return InkWell(
                        onTap: () {
                          setState(() {
                            selectedPaymentWeekIndex = i;
                            selectedDate = week.first;
                          });
                        },
                        borderRadius: BorderRadius.circular(12.0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: width,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12.0,
                            horizontal: 10.0,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? primaryColor
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(
                              color: isSelected
                                  ? primaryColor
                                  : const Color(0xFFCBD5E1),
                              width: isSelected ? 2.0 : 1.0,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: primaryColor.withValues(alpha: 0.3),
                                      blurRadius: 8.0,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (isSelected) ...[
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: Colors.white,
                                      size: 15,
                                    ),
                                    const SizedBox(width: 5),
                                  ],
                                  Text(
                                    'Week ${i + 1}',
                                    style: TextStyle(
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF0A183D),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$startDate - $endDate',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white70
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildDatePickerSection(
    BuildContext context,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    final weeks = _getWeeksOfMonth(selectedPaymentYear, selectedPaymentMonth);
    final weekDays = weeks[selectedPaymentWeekIndex!];
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Date within Week',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0A183D),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final weekStart = weekDays.first;
            final weekEnd = weekDays.last;
            final picked = await showDatePicker(
              context: context,
              initialDate:
                  selectedDate != null &&
                      selectedDate!.isAfter(
                        weekStart.subtract(const Duration(days: 1)),
                      ) &&
                      selectedDate!.isBefore(
                        weekEnd.add(const Duration(days: 1)),
                      )
                  ? selectedDate!
                  : weekStart,
              firstDate: weekStart,
              lastDate: weekEnd,
              builder: (context, child) {
                return Theme(
                  data: theme.copyWith(
                    colorScheme: theme.colorScheme.copyWith(
                      primary: primaryColor,
                      onPrimary: Colors.white,
                      surface: Colors.white,
                      onSurface: const Color(0xFF0A183D),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() => selectedDate = picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: 14.0,
              horizontal: 16.0,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0A183D).withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      color: primaryColor,
                      size: 20.0,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      selectedDate != null
                          ? DateFormat(
                              'EEE, MMM dd, yyyy',
                            ).format(selectedDate!)
                          : 'Select Date',
                      style: const TextStyle(
                        fontSize: 14.0,
                        color: Color(0xFF0A183D),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Color(0xFF64748B),
                  size: 15,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 4.0),
          child: Text(
            'Available range: ${DateFormat('MMM dd').format(weekDays.first)} - ${DateFormat('MMM dd').format(weekDays.last)}',
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
