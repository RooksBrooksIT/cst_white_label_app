import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../utils/responsive.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class SitePaymentScreen extends StatefulWidget {
  const SitePaymentScreen({super.key});

  @override
  _SitePaymentScreenState createState() => _SitePaymentScreenState();
}

class _SitePaymentScreenState extends State<SitePaymentScreen> {
  final Color mainColor = const Color(0xFF003768);

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
      final snapshot = await FirebaseFirestore.instance
          .collection('projectStages')
          .get()
          .timeout(
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
      final snapshot = await FirebaseFirestore.instance
          .collection('siteSupervisorMap')
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
        siteList = snapshot.docs.map((doc) {
          final data = doc.data();
          final display = (data['site'] ?? doc.id).toString();
          return {'id': doc.id.toString(), 'display': display};
        }).toList();
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
      final doc = await FirebaseFirestore.instance
          .collection('siteSupervisorMap')
          .doc(siteId)
          .get();
      if (doc.exists) {
        setState(() {
          supervisor = doc.data()?['supervisor'] ?? '';
          amount = (doc.data()?['amount'] ?? 0).toInt();
          amountController.text = amount == 0 ? '' : amount.toString();
        });
      } else {
        setState(() {
          supervisor = '';
          amount = 0;
          amountController.text = '';
        });
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

      final paymentDocRef = FirebaseFirestore.instance
          .collection('siteSupervisorPayments')
          .doc(docId);

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment Added Successfully!'),
          backgroundColor: mainColor,
          duration: Duration(seconds: 2),
        ),
      );

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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Site Payment',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1E293B),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.isMobile(context) ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          const SizedBox(height: 32),
          _buildForm(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.payments_rounded,
            color: colorScheme.primary,
            size: 32,
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment Entry',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                'Record site supervisor payments',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionTitle('Site Details'),
          const SizedBox(height: 16),
          _buildSiteDropdown(),
          const SizedBox(height: 16),
          _buildSupervisorField(),
          const SizedBox(height: 16),
          _buildAmountField(),
          const SizedBox(height: 16),
          _buildProjectStageDropdown(),
          const SizedBox(height: 32),
          _buildSectionTitle('Payment Period'),
          const SizedBox(height: 16),
          _buildPeriodSelection(),
          const SizedBox(height: 24),
          _buildWeeksSelection(),
          const SizedBox(height: 24),
          if (selectedPaymentWeekIndex != null) _buildDatePickerSection(),
          const SizedBox(height: 40),
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildSiteDropdown() {
    return DropdownButtonFormField<String>(
      value: selectedSiteId,
      isExpanded: true,
      dropdownColor: Colors.white,
      style: const TextStyle(color: Color(0xFF1E293B)),
      decoration: _inputDecoration('Select Site ID', Icons.place_rounded),
      items: siteList.map((site) {
        return DropdownMenuItem<String>(
          value: site['id'],
          child: Text(site['display'] ?? ''),
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
    );
  }

  Widget _buildSupervisorField() {
    return TextFormField(
      readOnly: true,
      controller: TextEditingController(text: supervisor),
      style: const TextStyle(color: Color(0xFF1E293B)),
      decoration: _inputDecoration('Supervisor', Icons.person_rounded),
    );
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller: amountController,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(color: Color(0xFF1E293B)),
      decoration: _inputDecoration('Amount', Icons.currency_rupee_rounded),
      onChanged: (value) {
        setState(() {
          amount = int.tryParse(value) ?? 0;
        });
      },
    );
  }

  Widget _buildProjectStageDropdown() {
    return DropdownButtonFormField<String>(
      value: selectedProjectStage,
      isExpanded: true,
      dropdownColor: Colors.white,
      style: const TextStyle(color: Color(0xFF1E293B)),
      decoration: _inputDecoration('Project Stage', Icons.flag_rounded),
      items: projectStages.map((stage) {
        return DropdownMenuItem<String>(value: stage, child: Text(stage));
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedProjectStage = value;
        });
      },
    );
  }

  Widget _buildPeriodSelection() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            value: selectedPaymentYear,
            dropdownColor: Colors.white,
            style: const TextStyle(color: Color(0xFF1E293B)),
            decoration: _inputDecoration('Year', Icons.calendar_today_rounded),
            items: paymentYears.map((y) {
              return DropdownMenuItem<int>(value: y, child: Text(y.toString()));
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedPaymentYear = value!;
                selectedPaymentWeekIndex = null;
              });
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<int>(
            value: selectedPaymentMonth,
            dropdownColor: Colors.white,
            style: const TextStyle(color: Color(0xFF1E293B)),
            decoration: _inputDecoration('Month', Icons.calendar_month_rounded),
            items: List.generate(12, (i) => i + 1).map((m) {
              return DropdownMenuItem<int>(
                value: m,
                child: Text(DateFormat.MMMM().format(DateTime(0, m))),
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

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: resetForm,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Reset'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _submitPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Submit Payment',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF64748B)),
      prefixIcon: Icon(icon, color: colorScheme.primary, size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Color(0xFF64748B),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildWeeksSelection() {
    final weeks = _getWeeksOfMonth(selectedPaymentYear, selectedPaymentMonth);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Select Week *'),
        const SizedBox(height: 12),
        weeks.isEmpty
            ? Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Text(
                  'No weeks available for selected month',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 12,
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
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width:
                          (MediaQuery.of(context).size.width - 80) /
                          2, // Explicit width for 2-column layout to prevent overflow
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Week ${i + 1}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$startDate - $endDate',
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected
                                  ? Colors.white.withOpacity(0.9)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
      ],
    );
  }

  Widget _buildDatePickerSection() {
    final weeks = _getWeeksOfMonth(selectedPaymentYear, selectedPaymentMonth);
    final weekDays = weeks[selectedPaymentWeekIndex!];
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Select Date within Week'),
        const SizedBox(height: 12),
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
            );
            if (picked != null) {
              setState(() => selectedDate = picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedDate != null
                      ? DateFormat('EEE, MMM dd, yyyy').format(selectedDate!)
                      : 'Select Date',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(
                  Icons.calendar_today_rounded,
                  color: colorScheme.primary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Available: ${DateFormat('MMM dd').format(weekDays.first)} - ${DateFormat('MMM dd').format(weekDays.last)}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }
}
