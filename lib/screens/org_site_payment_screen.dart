import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';

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
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 600;
    final isVerySmallScreen = mediaQuery.size.width < 400;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: mainColor,
        title: const Text(
          'Site Payment',
          style: TextStyle(),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: IconThemeData(),
      ),
      
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(maxWidth: 600),
            padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
            margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8.0 : 0.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [mainColor.withOpacity(0.10), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: mainColor.withOpacity(0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with icon and title
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: mainColor,
                      radius: isSmallScreen ? 20 : 28,
                      child: Icon(
                        Icons.payments,
                        
                        size: isSmallScreen ? 24 : 32,
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 12 : 16),
                    Expanded(
                      child: Text(
                        'Site Payment Entry',
                        style: TextStyle(
                          color: mainColor,
                          fontSize: isSmallScreen ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 24 : 32),

                // Site ID Dropdown
                _buildSectionTitle('Site ID *'),
                SizedBox(height: 8),
                _buildDropdownContainer(
                  child: DropdownButtonFormField<String>(
                    value: selectedSiteId,
                    isExpanded: true,
                    decoration: _inputDecoration(),
                    items: siteList.map((site) {
                      return DropdownMenuItem<String>(
                        value: site['id'],
                        child: Text(
                          site['display'] ?? '',
                          style: TextStyle(fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
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
                    hint: Text(
                      'Select Site ID',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                SizedBox(height: isSmallScreen ? 20 : 24),

                // Supervisor (auto-filled)
                _buildSectionTitle('Supervisor *'),
                SizedBox(height: 8),
                _buildTextFieldContainer(
                  child: TextFormField(
                    readOnly: true,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: mainColor,
                    ),
                    decoration: _inputDecoration(),
                    controller: TextEditingController(text: supervisor),
                    key: ValueKey(supervisor),
                  ),
                ),
                SizedBox(height: isSmallScreen ? 20 : 24),

                // Amount (editable, with rupee icon and only numbers allowed)
                _buildSectionTitle('Amount *'),
                SizedBox(height: 8),
                _buildTextFieldContainer(
                  child: TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: mainColor,
                    ),
                    decoration: _inputDecoration().copyWith(
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 12, right: 8),
                        child: Text(
                          '₹',
                          style: TextStyle(fontSize: 20, color: mainColor),
                        ),
                      ),
                      prefixIconConstraints: BoxConstraints(
                        minWidth: 0,
                        minHeight: 0,
                      ),
                      hintText: 'Enter amount',
                    ),
                    onChanged: (value) {
                      setState(() {
                        amount = int.tryParse(value) ?? 0;
                      });
                    },
                  ),
                ),
                SizedBox(height: isSmallScreen ? 20 : 24),

                // Project Stage Dropdown
                _buildSectionTitle('Project Stage *'),
                SizedBox(height: 8),
                _buildDropdownContainer(
                  child: DropdownButtonFormField<String>(
                    value: selectedProjectStage,
                    isExpanded: true,
                    decoration: _inputDecoration(),
                    items: projectStages.map((stage) {
                      return DropdownMenuItem<String>(
                        value: stage,
                        child: Text(
                          stage,
                          style: TextStyle(fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedProjectStage = value;
                      });
                    },
                    hint: Text(
                      'Select Project Stage',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                SizedBox(height: isSmallScreen ? 20 : 24),

                // Year and Month
                _buildSectionTitle('Year and Month *'),
                SizedBox(height: 8),
                isSmallScreen ? _buildYearMonthColumn() : _buildYearMonthRow(),
                SizedBox(height: isSmallScreen ? 16 : 24),

                // Weeks Selection
                _buildWeeksSection(),
                SizedBox(height: isSmallScreen ? 20 : 24),

                // Date Picker (only show if week is selected)
                if (selectedPaymentWeekIndex != null) _buildDatePickerSection(),

                SizedBox(height: isSmallScreen ? 28 : 36),

                // Buttons
                _buildActionButtons(isSmallScreen, isVerySmallScreen),

                // Required fields note
                SizedBox(height: 16),
                Text(
                  '* indicates required fields',
                  style: TextStyle(
                    
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: mainColor,
        fontSize: 16,
      ),
    );
  }

  Widget _buildDropdownContainer({required Widget child}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: mainColor.withOpacity(0.07),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildTextFieldContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: mainColor.withOpacity(0.07),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: mainColor.withOpacity(0.1)),
      ),
    );
  }

  Widget _buildYearMonthRow() {
    return Row(
      children: [
        Expanded(
          child: _buildDropdownContainer(
            child: DropdownButtonFormField<int>(
              value: selectedPaymentYear,
              isExpanded: true,
              decoration: _inputDecoration(),
              items: paymentYears.map((y) {
                return DropdownMenuItem<int>(
                  value: y,
                  child: Text(
                    y.toString(),
                    style: TextStyle(fontWeight: FontWeight.w500),
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
        SizedBox(width: 12),
        Expanded(
          child: _buildDropdownContainer(
            child: DropdownButtonFormField<int>(
              value: selectedPaymentMonth,
              isExpanded: true,
              decoration: _inputDecoration(),
              items: List.generate(12, (i) => i + 1).map((m) {
                return DropdownMenuItem<int>(
                  value: m,
                  child: Text(
                    DateFormat.MMMM().format(DateTime(0, m)),
                    style: TextStyle(fontWeight: FontWeight.w500),
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

  Widget _buildYearMonthColumn() {
    return Column(
      children: [
        _buildDropdownContainer(
          child: DropdownButtonFormField<int>(
            value: selectedPaymentYear,
            isExpanded: true,
            decoration: _inputDecoration(),
            items: paymentYears.map((y) {
              return DropdownMenuItem<int>(
                value: y,
                child: Text(
                  y.toString(),
                  style: TextStyle(fontWeight: FontWeight.w500),
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
        SizedBox(height: 12),
        _buildDropdownContainer(
          child: DropdownButtonFormField<int>(
            value: selectedPaymentMonth,
            isExpanded: true,
            decoration: _inputDecoration(),
            items: List.generate(12, (i) => i + 1).map((m) {
              return DropdownMenuItem<int>(
                value: m,
                child: Text(
                  DateFormat.MMMM().format(DateTime(0, m)),
                  style: TextStyle(fontWeight: FontWeight.w500),
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

  Widget _buildWeeksSection() {
    final weeks = _getWeeksOfMonth(selectedPaymentYear, selectedPaymentMonth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Select Week *'),
        SizedBox(height: 8),
        weeks.isEmpty
            ? Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'No weeks available for selected month',
                  style: TextStyle(),
                ),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(weeks.length, (i) {
                  final week = weeks[i];
                  final startDate = DateFormat('MMM dd').format(week.first);
                  final endDate = DateFormat('MMM dd').format(week.last);

                  return ChoiceChip(
                    label: Text(
                      'Week ${i + 1}\n($startDate - $endDate)',
                      style: TextStyle(
                        fontSize: 12,
                        color: selectedPaymentWeekIndex == i
                            ? Colors.white
                            : mainColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    selected: selectedPaymentWeekIndex == i,
                    selectedColor: mainColor,
                    backgroundColor: Color(0xFFF2EAEA),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        selectedPaymentWeekIndex = i;
                        // Set default date to first day of selected week
                        selectedDate = week.first;
                      });
                    },
                  );
                }),
              ),
      ],
    );
  }

  Widget _buildDatePickerSection() {
    final weeks = _getWeeksOfMonth(selectedPaymentYear, selectedPaymentMonth);
    final weekDays = weeks[selectedPaymentWeekIndex!];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Select Date within Week'),
        SizedBox(height: 8),
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
                  data: ThemeData.light().copyWith(
                    primaryColor: mainColor,
                    colorScheme: ColorScheme.light(primary: mainColor),
                    buttonTheme: ButtonThemeData(
                      textTheme: ButtonTextTheme.primary,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() {
                selectedDate = picked;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              
              border: Border.all(color: mainColor.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: mainColor.withOpacity(0.07),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedDate != null
                      ? DateFormat('EEE, MMM dd, yyyy').format(selectedDate!)
                      : 'Select Date',
                  style: TextStyle(
                    fontSize: 16,
                    color: mainColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(Icons.calendar_today, color: mainColor, size: 20),
              ],
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Available dates: ${DateFormat('MMM dd').format(weekDays.first)} - ${DateFormat('MMM dd').format(weekDays.last)}',
          style: TextStyle( fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isSmallScreen, bool isVerySmallScreen) {
    if (isVerySmallScreen) {
      return Column(
        children: [
          _buildAddButton(),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildResetButton()),
              SizedBox(width: 12),
              Expanded(child: _buildCancelButton()),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: _buildAddButton()),
        SizedBox(width: isSmallScreen ? 8 : 12),
        Expanded(child: _buildResetButton()),
        SizedBox(width: isSmallScreen ? 8 : 12),
        Expanded(child: _buildCancelButton()),
      ],
    );
  }

  Widget _buildAddButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: mainColor,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        shadowColor: mainColor.withOpacity(0.2),
      ),
      onPressed: _submitPayment,
      child: Text(
        'ADD PAYMENT',
        style: TextStyle(
          fontSize: 16,
          
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildResetButton() {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: mainColor, width: 2),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: resetForm,
      child: Text(
        'RESET',
        style: TextStyle(
          fontSize: 16,
          color: mainColor,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.grey, width: 2),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () {
        Navigator.pop(context);
      },
      child: Text(
        'CANCEL',
        style: TextStyle(
          fontSize: 16,
          
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
