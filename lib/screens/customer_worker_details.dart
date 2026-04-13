import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../utils/responsive.dart';

class CustomerWorkerDetails extends StatefulWidget {
  final String siteId;

  const CustomerWorkerDetails({Key? key, required this.siteId})
    : super(key: key);

  @override
  State<CustomerWorkerDetails> createState() => _CustomerWorkerDetailsState();
}

class _CustomerWorkerDetailsState extends State<CustomerWorkerDetails> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DateTime? _selectedDate;
  String _selectedMonth = '';
  String _selectedYear = '';

  @override
  void initState() {
    super.initState();
    // Initialize with current date
    final now = DateTime.now();
    _selectedMonth = DateFormat('MMMM').format(now);
    _selectedYear = now.year.toString();
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Worker Details',
      onBack: () => Navigator.pop(context),
      body: Column(
        children: [
          // Filter Section
          _buildFilterSection(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('workersAttendance')
                  .where('site', isEqualTo: widget.siteId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No worker data found',
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 16),
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  );
                }

                final documents = snapshot.data!.docs;

                // Filter documents based on selected date/month/year
                final filteredDocs = _filterDocuments(documents);

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Text(
                      'No data found for selected filter',
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 16),
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final workers =
                        data['workers'] as Map<String, dynamic>? ?? {};
                    final day = data['Day'] ?? 'Unknown Date';

                    return _buildDayCard(day, workers);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return GlassCard(
      margin: EdgeInsets.all(Responsive.isMobile(context) ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter attendance records:',
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 16),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Date Picker
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _selectedDate != null
                        ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                        : 'Select Date',
                  ),
                  onPressed: _showDatePicker,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Clear Date Filter
              if (_selectedDate != null)
                IconButton(
                  icon: const Icon(
                    Icons.clear,
                    size: 20,
                    color: Color(0xFF64748B),
                  ),
                  onPressed: _clearDateFilter,
                  tooltip: 'Clear date filter',
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Month Dropdown
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedMonth.isNotEmpty ? _selectedMonth : null,
                  decoration: const InputDecoration(
                    labelText: 'Month',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  items: _getMonths(),
                  onChanged: (value) {
                    setState(() {
                      _selectedMonth = value!;
                      _selectedDate = null; // Clear date when month is selected
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Year Dropdown
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedYear.isNotEmpty ? _selectedYear : null,
                  decoration: const InputDecoration(
                    labelText: 'Year',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  items: _getYears(),
                  onChanged: (value) {
                    setState(() {
                      _selectedYear = value!;
                      _selectedDate = null; // Clear date when year is selected
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Clear All Filters
          if (_selectedDate != null ||
              _selectedMonth.isNotEmpty ||
              _selectedYear.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _clearAllFilters,
                child: Text(
                  'Clear All Filters',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<String>> _getMonths() {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months.map((month) {
      return DropdownMenuItem<String>(value: month, child: Text(month));
    }).toList();
  }

  List<DropdownMenuItem<String>> _getYears() {
    final currentYear = DateTime.now().year;
    final years = List.generate(
      10,
      (index) => (currentYear - index).toString(),
    );
    return years.map((year) {
      return DropdownMenuItem<String>(value: year, child: Text(year));
    }).toList();
  }

  void _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedMonth = ''; // Clear month filter
        _selectedYear = ''; // Clear year filter
      });
    }
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDate = null;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedDate = null;
      _selectedMonth = '';
      _selectedYear = '';
    });
  }

  List<QueryDocumentSnapshot> _filterDocuments(
    List<QueryDocumentSnapshot> documents,
  ) {
    if (_selectedDate == null &&
        _selectedMonth.isEmpty &&
        _selectedYear.isEmpty) {
      return documents; // Return all documents if no filter is applied
    }

    return documents.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final dayString = data['Day']?.toString() ?? '';

      if (dayString.isEmpty) return false;

      try {
        // Parse the date string (adjust format based on your Firestore date format)
        final dayDate = DateFormat('dd/MM/yyyy').parse(dayString);

        if (_selectedDate != null) {
          // Filter by specific date
          return _selectedDate!.day == dayDate.day &&
              _selectedDate!.month == dayDate.month &&
              _selectedDate!.year == dayDate.year;
        } else {
          // Filter by month and/or year
          bool matchesMonth =
              _selectedMonth.isEmpty ||
              DateFormat('MMMM').format(dayDate) == _selectedMonth;
          bool matchesYear =
              _selectedYear.isEmpty || dayDate.year.toString() == _selectedYear;

          return matchesMonth && matchesYear;
        }
      } catch (e) {
        // If date parsing fails, check if the date string contains the filter criteria
        if (_selectedDate != null) {
          final selectedDateString = DateFormat(
            'dd/MM/yyyy',
          ).format(_selectedDate!);
          return dayString == selectedDateString;
        } else {
          bool matchesMonth =
              _selectedMonth.isEmpty ||
              dayString.toLowerCase().contains(_selectedMonth.toLowerCase());
          bool matchesYear =
              _selectedYear.isEmpty || dayString.contains(_selectedYear);

          return matchesMonth && matchesYear;
        }
      }
    }).toList();
  }

  Widget _buildDayCard(String day, Map<String, dynamic> workers) {
    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Date: $day',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 18),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${workers.length} Workers',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: Color(0xFFE2E8F0), height: 24),
          const SizedBox(height: 8),
          ...workers.entries.map((workerEntry) {
            final workerName = workerEntry.key;
            final workerData = workerEntry.value as Map<String, dynamic>;

            return _buildWorkerTile(workerName, workerData);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildWorkerTile(String name, Map<String, dynamic> data) {
    final attendance = data['attendance'] ?? 'Unknown';
    final designation = data['designation'] ?? 'Unknown';
    final salary = data['salary'] ?? 0;

    Color attendanceColor = Colors.grey;
    if (attendance == 'Present') {
      attendanceColor = Colors.green;
    } else if (attendance == 'Absent') {
      attendanceColor = Colors.red;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Worker avatar/icon
          CircleAvatar(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.2),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Worker details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  designation,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          // Attendance and Salary
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: attendanceColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: attendanceColor),
                ),
                child: Text(
                  attendance,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: attendanceColor,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '₹$salary',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
