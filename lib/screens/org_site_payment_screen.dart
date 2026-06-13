import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../services/firestore_service.dart';
import 'package:demo_cst/utils/responsive.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_text_field.dart';

class SitePaymentScreen extends StatefulWidget {
  const SitePaymentScreen({super.key});

  @override
  _SitePaymentScreenState createState() => _SitePaymentScreenState();
}

class _SitePaymentScreenState extends State<SitePaymentScreen> {
  // Site list for dropdown (list of {id, display})
  List<Map<String, String>> siteList = [];

  String? selectedSiteId;
  String supervisor = '';
  int amount = 0;
  DateTime? selectedDate;
  final TextEditingController amountController = TextEditingController();

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
      // Get the first day of the month
      DateTime firstDay = DateTime(year, month, 1);

      // Get the last day of the month by going to the first day of next month and subtracting 1 day
      DateTime lastDayOfMonth = month == 12
          ? DateTime(year + 1, 1, 1).subtract(const Duration(days: 1))
          : DateTime(year, month + 1, 1).subtract(const Duration(days: 1));

      // Calculate the start of the first week (Monday-based)
      int dayOffset = firstDay.weekday - 1; // 0 for Monday
      DateTime weekStart = firstDay.subtract(Duration(days: dayOffset));

      // Generate weeks until we've covered the entire month
      while (weekStart.isBefore(lastDayOfMonth) ||
          weekStart.isAtSameMomentAs(lastDayOfMonth)) {
        List<DateTime> week = [];

        // Add days of this week that fall in the current month
        for (int i = 0; i < 7; i++) {
          DateTime day = weekStart.add(Duration(days: i));
          if (day.month == month && day.year == year) {
            week.add(day);
          }
        }

        if (week.isNotEmpty) {
          weeks.add(week);
        }

        // Move to next week
        weekStart = weekStart.add(const Duration(days: 7));

        // Break if we've gone past the month
        if (weekStart.month > month || (weekStart.month == 1 && month == 12)) {
          break;
        }
      }
    } catch (e) {
      print('Error calculating weeks of month: $e');
      // Return empty list if there's an error
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
      print('Timeout fetching project stages: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load project stages')),
        );
      }
    } catch (e) {
      print('Error fetching project stages: $e');
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
          return {'id': doc.id.toString(), 'display': display};
        }).toList()..sort((a, b) => a['display']!.compareTo(b['display']!));
      });
    } on TimeoutException catch (e) {
      print('Timeout fetching site IDs: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load sites. Please retry.')),
        );
      }
    } catch (e) {
      print('Error fetching site IDs: $e');
    }
  }

  Future<void> _fetchSupervisorForSite(String siteId) async {
    try {
      final doc = await FirestoreService.siteSupervisorMap.doc(siteId).get();

      if (doc.exists) {
        setState(() {
          supervisor = doc.data()?['supervisor'] ?? '';
          amount = (doc.data()?['amount'] ?? 0).toInt();
          amountController.text = amount == 0 ? '' : amount.toString();
        });
      } else {
        // Fallback: search by 'site' field in siteSupervisorMap
        final query = await FirestoreService.siteSupervisorMap
            .where('site', isEqualTo: siteId)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          final data = query.docs.first.data();
          setState(() {
            supervisor = data['supervisor'] ?? '';
            amount = (data['amount'] ?? 0).toInt();
            amountController.text = amount == 0 ? '' : amount.toString();
          });
        } else {
          setState(() {
            supervisor = 'Not Assigned';
            amount = 0;
            amountController.text = '';
          });
        }
      }
    } catch (e) {
      print('Error fetching supervisor: $e');
    }
  }

  void resetForm() {
    setState(() {
      selectedSiteId = null;
      supervisor = '';
      amount = 0;
      amountController.text = '';
      selectedDate = DateTime.now();
      selectedProjectStage = null;
      selectedPaymentWeekIndex = null;
      selectedPaymentYear = DateTime.now().year;
      selectedPaymentMonth = DateTime.now().month;
    });
  }

  Future<void> _submitPayment() async {
    // Validate all required fields
    if (selectedSiteId == null ||
        supervisor.isEmpty ||
        amount <= 0 ||
        selectedProjectStage == null ||
        selectedPaymentWeekIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please fill all required fields including week selection!',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      // Parse projectName from site dropdown display value
      final siteMap = siteList.firstWhere(
        (s) => s['id'] == selectedSiteId,
        orElse: () => {'display': selectedSiteId!},
      );
      final siteDisplay = siteMap['display'] ?? selectedSiteId!;
      String projectName = '';
      if (siteDisplay.contains('_')) {
        final parts = siteDisplay.split('_');
        if (parts.length > 1) {
          projectName = parts.sublist(1).join('_');
        }
      }
      if (projectName.isEmpty) projectName = siteDisplay;

      // Date formatting
      final date = selectedDate ?? DateTime.now();
      final year = date.year;
      final monthStr = DateFormat('MMM').format(date);
      final weekIndex = selectedPaymentWeekIndex! + 1;
      final paymentPeriod = '${year}_${monthStr}_Week$weekIndex';
      final docId = '${siteDisplay}_$paymentPeriod';

      final paymentDocRef = FirestoreService.siteSupervisorPayments.doc(docId);

      final paymentDocSnap = await paymentDocRef.get();
      List<dynamic> payments = [];
      if (paymentDocSnap.exists) {
        final data = paymentDocSnap.data();
        payments = List.from(data?['payments'] ?? []);
      }

      // Add or update payment for the selected day
      final paymentDateStr = DateFormat('yyyy-MM-dd').format(date);
      final existingIndex = payments.indexWhere(
        (p) => p['paymentDate'] == paymentDateStr,
      );

      if (existingIndex >= 0) {
        payments[existingIndex]['paymentAmount'] = amount;
      } else {
        payments.add({'paymentDate': paymentDateStr, 'paymentAmount': amount});
      }

      // Calculate the new total for the week
      int newTotal = payments.fold(
        0,
        (int sum, p) => sum + ((p['paymentAmount'] ?? 0) as int),
      );

      await paymentDocRef.set({
        'paymentAmount': newTotal,
        'payments': payments,
        'paymentPeriod': paymentPeriod,
        'projectName': projectName,
        'projectStage': selectedProjectStage,
        'siteId': siteDisplay,
        'supervisorName': supervisor,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        final themeColor = Theme.of(context).primaryColor;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Payment Added Successfully!'),
            backgroundColor: themeColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      resetForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding payment: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    return GlassScaffold(
      title: 'Site Payment',
      onBack: () => Navigator.pop(context),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 600),
          child: _buildBody(context, isDesktop, isTablet, isMobile),
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
      padding: EdgeInsets.all(isDesktop ? 40.0 : (isTablet ? 32.0 : 16.0)),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 900.0 : double.infinity,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, isDesktop, isTablet, isMobile),
              SizedBox(height: isDesktop ? 40.0 : 32.0),
              _buildForm(context, isDesktop, isTablet, isMobile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(isDesktop ? 16.0 : 12.0),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.payments_rounded,
            color: colorScheme.primary,
            size: isDesktop ? 40.0 : 32.0,
          ),
        ),
        SizedBox(width: isDesktop ? 20.0 : 16.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment Entry',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  fontSize: isDesktop ? 26.0 : null,
                ),
              ),
              Text(
                'Record site supervisor payments',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: isDesktop ? 15.0 : null,
                ),
              ),
            ],
          ),
        ),
      ],
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
        GlassCard(
          padding: EdgeInsets.all(isDesktop ? 24.0 : 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(
                context,
                'Site Details',
                isDesktop,
                isTablet,
                isMobile,
              ),
              SizedBox(height: isDesktop ? 24.0 : 20.0),
              _buildSiteDropdown(context, isDesktop, isTablet, isMobile),
              SizedBox(height: isDesktop ? 24.0 : 20.0),
              _buildSupervisorField(context),
              SizedBox(height: isDesktop ? 24.0 : 20.0),
              _buildAmountField(context),
              SizedBox(height: isDesktop ? 24.0 : 20.0),
              _buildProjectStageDropdown(
                context,
                isDesktop,
                isTablet,
                isMobile,
              ),
            ],
          ),
        ),
        SizedBox(height: isDesktop ? 32.0 : 24.0),
        GlassCard(
          padding: EdgeInsets.all(isDesktop ? 24.0 : 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(
                context,
                'Payment Period',
                isDesktop,
                isTablet,
                isMobile,
              ),
              SizedBox(height: isDesktop ? 24.0 : 20.0),
              _buildPeriodSelection(context, isDesktop, isTablet, isMobile),
              SizedBox(height: isDesktop ? 32.0 : 24.0),
              _buildWeeksSelection(context, isDesktop, isTablet, isMobile),
              if (selectedPaymentWeekIndex != null) ...[
                SizedBox(height: isDesktop ? 32.0 : 24.0),
                _buildDatePickerSection(context, isDesktop, isTablet, isMobile),
              ],
            ],
          ),
        ),
        SizedBox(height: isDesktop ? 48.0 : 40.0),
        _buildActionButtons(context, isDesktop, isTablet, isMobile),
      ],
    );
  }

  Widget _buildSiteDropdown(
    BuildContext context,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    final theme = Theme.of(context);
    return _buildDropdownContainer(
      context,
      label: 'Site ID',
      isDesktop: isDesktop,
      isTablet: isTablet,
      isMobile: isMobile,
      child: DropdownButtonFormField<String>(
        value: selectedSiteId,
        isExpanded: true,
        dropdownColor: theme.cardColor,
        decoration: InputDecoration(
          hintText: 'Select Site ID',
          prefixIcon: Icon(
            Icons.place_rounded,
            color: theme.primaryColor,
            size: isDesktop ? 24.0 : 20.0,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 16.0 : 12.0,
            vertical: isDesktop ? 12.0 : 8.0,
          ),
        ),
        items: siteList.map((site) {
          return DropdownMenuItem<String>(
            value: site['id'],
            child: Text(
              site['display'] ?? '',
              style: TextStyle(fontSize: isDesktop ? 15.0 : 13.0),
            ),
          );
        }).toList(),
        onChanged: (value) async {
          setState(() {
            selectedSiteId = value;
            supervisor = '';
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
    return GlassTextField(
      controller: TextEditingController(text: supervisor),
      label: 'Supervisor',
      icon: Icons.person_rounded,
      readOnly: true,
    );
  }

  Widget _buildAmountField(BuildContext context) {
    return GlassTextField(
      controller: amountController,
      label: 'Amount',
      icon: Icons.currency_rupee_rounded,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (value) {
        setState(() {
          amount = int.tryParse(value) ?? 0;
        });
      },
    );
  }

  Widget _buildProjectStageDropdown(
    BuildContext context,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    final theme = Theme.of(context);
    return _buildDropdownContainer(
      context,
      label: 'Project Stage',
      isDesktop: isDesktop,
      isTablet: isTablet,
      isMobile: isMobile,
      child: DropdownButtonFormField<String>(
        value: selectedProjectStage,
        isExpanded: true,
        dropdownColor: theme.cardColor,
        decoration: InputDecoration(
          hintText: 'Select Project Stage',
          prefixIcon: Icon(
            Icons.flag_rounded,
            color: theme.primaryColor,
            size: isDesktop ? 24.0 : 20.0,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 16.0 : 12.0,
            vertical: isDesktop ? 12.0 : 8.0,
          ),
        ),
        items: projectStages.map((stage) {
          return DropdownMenuItem<String>(
            value: stage,
            child: Text(
              stage,
              style: TextStyle(fontSize: isDesktop ? 15.0 : 13.0),
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
    final theme = Theme.of(context);

    if (isMobile) {
      return Column(
        children: [
          _buildDropdownContainer(
            context,
            label: 'Year',
            isDesktop: isDesktop,
            isTablet: isTablet,
            isMobile: isMobile,
            child: DropdownButtonFormField<int>(
              value: selectedPaymentYear,
              isExpanded: true,
              dropdownColor: theme.cardColor,
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.calendar_today_rounded,
                  color: theme.primaryColor,
                  size: isDesktop ? 24.0 : 20.0,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 16.0 : 12.0,
                  vertical: isDesktop ? 12.0 : 8.0,
                ),
              ),
              items: paymentYears.map((y) {
                return DropdownMenuItem<int>(
                  value: y,
                  child: Text(
                    y.toString(),
                    style: TextStyle(fontSize: isDesktop ? 15.0 : 13.0),
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
          ),
          SizedBox(height: isDesktop ? 20.0 : 16.0),
          _buildDropdownContainer(
            context,
            label: 'Month',
            isDesktop: isDesktop,
            isTablet: isTablet,
            isMobile: isMobile,
            child: DropdownButtonFormField<int>(
              value: selectedPaymentMonth,
              isExpanded: true,
              dropdownColor: theme.cardColor,
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.calendar_month_rounded,
                  color: theme.primaryColor,
                  size: isDesktop ? 24.0 : 20.0,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 16.0 : 12.0,
                  vertical: isDesktop ? 12.0 : 8.0,
                ),
              ),
              items: List.generate(12, (i) => i + 1).map((m) {
                return DropdownMenuItem<int>(
                  value: m,
                  child: Text(
                    DateFormat.MMMM().format(DateTime(0, m)),
                    style: TextStyle(fontSize: isDesktop ? 15.0 : 13.0),
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
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildDropdownContainer(
            context,
            label: 'Year',
            isDesktop: isDesktop,
            isTablet: isTablet,
            isMobile: isMobile,
            child: DropdownButtonFormField<int>(
              value: selectedPaymentYear,
              isExpanded: true,
              dropdownColor: theme.cardColor,
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.calendar_today_rounded,
                  color: theme.primaryColor,
                  size: isDesktop ? 24.0 : 20.0,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 16.0 : 12.0,
                  vertical: isDesktop ? 12.0 : 8.0,
                ),
              ),
              items: paymentYears.map((y) {
                return DropdownMenuItem<int>(
                  value: y,
                  child: Text(
                    y.toString(),
                    style: TextStyle(fontSize: isDesktop ? 15.0 : 13.0),
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
          ),
        ),
        SizedBox(width: isDesktop ? 20.0 : 16.0),
        Expanded(
          child: _buildDropdownContainer(
            context,
            label: 'Month',
            isDesktop: isDesktop,
            isTablet: isTablet,
            isMobile: isMobile,
            child: DropdownButtonFormField<int>(
              value: selectedPaymentMonth,
              isExpanded: true,
              dropdownColor: theme.cardColor,
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.calendar_month_rounded,
                  color: theme.primaryColor,
                  size: isDesktop ? 24.0 : 20.0,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 16.0 : 12.0,
                  vertical: isDesktop ? 12.0 : 8.0,
                ),
              ),
              items: List.generate(12, (i) => i + 1).map((m) {
                return DropdownMenuItem<int>(
                  value: m,
                  child: Text(
                    DateFormat.MMMM().format(DateTime(0, m)),
                    style: TextStyle(fontSize: isDesktop ? 15.0 : 13.0),
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
          ),
        ),
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.0, bottom: isDesktop ? 12.0 : 8.0),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: isDesktop ? 15.0 : null,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: theme.dividerColor),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: resetForm,
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.onSurfaceVariant,
              side: BorderSide(color: theme.dividerColor),
              padding: EdgeInsets.symmetric(vertical: isDesktop ? 20.0 : 16.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            child: Text(
              'Reset',
              style: TextStyle(fontSize: isDesktop ? 15.0 : 13.0),
            ),
          ),
        ),
        SizedBox(width: isDesktop ? 20.0 : 16.0),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _submitPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: isDesktop ? 20.0 : 16.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              elevation: 0,
            ),
            child: Text(
              'Submit Payment',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimary,
                fontSize: isDesktop ? 15.0 : 13.0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(
    BuildContext context,
    String title,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(left: 4.0),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
          letterSpacing: 1.2,
          fontSize: isDesktop ? 14.0 : null,
        ),
      ),
    );
  }

  Widget _buildWeeksSelection(
    BuildContext context,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    final weeks = _getWeeksOfMonth(selectedPaymentYear, selectedPaymentMonth);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          context,
          'Select Week *',
          isDesktop,
          isTablet,
          isMobile,
        ),
        SizedBox(height: isDesktop ? 16.0 : 12.0),
        weeks.isEmpty
            ? Container(
                padding: EdgeInsets.all(isDesktop ? 20.0 : 16.0),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Text(
                  'No weeks available for selected month',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    fontSize: isDesktop ? 14.0 : 12.0,
                  ),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final double spacing = isDesktop ? 16.0 : 12.0;
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
                        child: Container(
                          width: width,
                          padding: EdgeInsets.symmetric(
                            vertical: isDesktop ? 16.0 : 12.0,
                            horizontal: isDesktop ? 12.0 : 8.0,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colorScheme.primary
                                : theme.scaffoldBackgroundColor.withValues(
                                    alpha: 0.5,
                                  ),
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(
                              color: isSelected
                                  ? colorScheme.primary
                                  : theme.dividerColor,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: colorScheme.primary.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 8.0,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Week ${i + 1}',
                                style: TextStyle(
                                  fontSize: isDesktop ? 16.0 : 14.0,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSurface,
                                ),
                              ),
                              SizedBox(height: isDesktop ? 6.0 : 4.0),
                              Text(
                                '$startDate - $endDate',
                                style: TextStyle(
                                  fontSize: isDesktop ? 13.0 : 11.0,
                                  color: isSelected
                                      ? colorScheme.onPrimary.withValues(
                                          alpha: 0.9,
                                        )
                                      : colorScheme.onSurfaceVariant,
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
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          context,
          'Select Date within Week',
          isDesktop,
          isTablet,
          isMobile,
        ),
        SizedBox(height: isDesktop ? 16.0 : 12.0),
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
                    colorScheme: colorScheme.copyWith(
                      primary: colorScheme.primary,
                      onPrimary: colorScheme.onPrimary,
                      surface: theme.cardColor,
                      onSurface: colorScheme.onSurface,
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
            padding: EdgeInsets.symmetric(
              vertical: isDesktop ? 20.0 : 16.0,
              horizontal: isDesktop ? 20.0 : 16.0,
            ),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      color: colorScheme.primary,
                      size: isDesktop ? 24.0 : 20.0,
                    ),
                    SizedBox(width: isDesktop ? 16.0 : 12.0),
                    Text(
                      selectedDate != null
                          ? DateFormat(
                              'EEE, MMM dd, yyyy',
                            ).format(selectedDate!)
                          : 'Select Date',
                      style: TextStyle(
                        fontSize: isDesktop ? 17.0 : 16.0,
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  size: isDesktop ? 20.0 : 16.0,
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: isDesktop ? 12.0 : 8.0),
        Padding(
          padding: EdgeInsets.only(left: 4.0),
          child: Text(
            'Available: ${DateFormat('MMM dd').format(weekDays.first)} - ${DateFormat('MMM dd').format(weekDays.last)}',
            style: TextStyle(
              fontSize: isDesktop ? 13.0 : 12.0,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }
}
