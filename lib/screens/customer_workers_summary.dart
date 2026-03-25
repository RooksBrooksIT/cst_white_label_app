import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_card.dart';
import '../utils/responsive.dart';

class CustomerWorkersSummary extends StatefulWidget {
  final String siteId;

  const CustomerWorkersSummary({Key? key, required this.siteId})
    : super(key: key);

  @override
  _CustomerWorkersSummaryState createState() => _CustomerWorkersSummaryState();
}

class _CustomerWorkersSummaryState extends State<CustomerWorkersSummary> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _filterType = 'all';
  DateTime? _selectedDate;
  DateTime? _selectedMonth;
  DateTime? _selectedYear;

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Worker Summary',
      onBack: () => Navigator.pop(context),
      actions: [
        IconButton(
          icon: const Icon(Icons.filter_alt, color: Colors.white),
          onPressed: _showFilterDialog,
        ),
      ],
      body: Column(
        children: [
          // Filter Summary
          _buildFilterSummary(),

          // Statistics Overview
          _buildStatisticsOverview(),

          // Worker List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getFilteredStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No worker data found',
                      style: TextStyle(fontSize: Responsive.fontSize(context, 16), color: Colors.white70),
                    ),
                  );
                }

                // Process data to group by worker
                final workerSummary = _processWorkerSummary(
                  snapshot.data!.docs,
                );

                return ListView.builder(
                  itemCount: workerSummary.length,
                  itemBuilder: (context, index) {
                    final worker = workerSummary[index];
                    return _buildWorkerSummaryCard(worker, index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSummary() {
    String filterText = 'Showing: All Records';

    switch (_filterType) {
      case 'date':
        if (_selectedDate != null) {
          filterText =
              'Showing: ${DateFormat('dd MMM yyyy').format(_selectedDate!)}';
        }
        break;
      case 'month':
        if (_selectedMonth != null) {
          filterText =
              'Showing: ${DateFormat('MMM yyyy').format(_selectedMonth!)}';
        }
        break;
      case 'year':
        if (_selectedYear != null) {
          filterText =
              'Showing: Year ${DateFormat('yyyy').format(_selectedYear!)}';
        }
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            filterText,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: Responsive.fontSize(context, 14),
            ),
          ),
          if (_filterType != 'all')
            IconButton(
              icon: const Icon(Icons.clear, size: 20, color: Colors.white60),
              onPressed: _clearFilters,
              tooltip: 'Clear filter',
            ),
        ],
      ),
    );
  }

  Widget _buildStatisticsOverview() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getFilteredStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox();
        }

        final stats = _calculateOverallStatistics(snapshot.data!.docs);

        return GlassCard(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Overview',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 18),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCircle(
                      'Total Workers',
                      stats.totalWorkers.toString(),
                      Colors.blue,
                    ),
                    _buildStatCircle(
                      'Present Days',
                      stats.totalPresent.toString(),
                      Colors.green,
                    ),
                    _buildStatCircle(
                      'Absent Days',
                      stats.totalAbsent.toString(),
                      Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCircle(
                      'Overtime',
                      stats.totalOvertime.toString(),
                      Colors.orange,
                    ),
                    _buildStatCircle(
                      'Half Days',
                      stats.totalHalfday.toString(),
                      Colors.amber,
                    ),
                    _buildStatCircle(
                      'Total Earnings',
                      '₹${stats.totalEarnings}',
                      Colors.green,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCircle(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white60),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Stream<QuerySnapshot> _getFilteredStream() {
    Query query = _firestore
        .collection('workersAttendance')
        .where('site', isEqualTo: widget.siteId);

    switch (_filterType) {
      case 'date':
        if (_selectedDate != null) {
          final startOfDay = DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
          );
          final endOfDay = startOfDay.add(const Duration(days: 1));
          query = query
              .where(
                'day',
                isGreaterThanOrEqualTo: DateFormat(
                  'yyyy-MM-dd',
                ).format(startOfDay),
              )
              .where(
                'day',
                isLessThan: DateFormat('yyyy-MM-dd').format(endOfDay),
              );
        }
        break;
      case 'month':
        if (_selectedMonth != null) {
          final firstDay = DateTime(
            _selectedMonth!.year,
            _selectedMonth!.month,
            1,
          );
          final lastDay = DateTime(
            _selectedMonth!.year,
            _selectedMonth!.month + 1,
            0,
          );
          query = query
              .where(
                'day',
                isGreaterThanOrEqualTo: DateFormat(
                  'yyyy-MM-dd',
                ).format(firstDay),
              )
              .where(
                'day',
                isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(lastDay),
              );
        }
        break;
      case 'year':
        if (_selectedYear != null) {
          final firstDay = DateTime(_selectedYear!.year, 1, 1);
          final lastDay = DateTime(_selectedYear!.year, 12, 31);
          query = query
              .where(
                'day',
                isGreaterThanOrEqualTo: DateFormat(
                  'yyyy-MM-dd',
                ).format(firstDay),
              )
              .where(
                'day',
                isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(lastDay),
              );
        }
        break;
    }

    return query.snapshots();
  }

  Future<void> _showFilterDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Filter Reports',
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFilterOption(
              Icons.calendar_today,
              'Specific Date',
              _selectedDate != null
                  ? DateFormat('dd MMM yyyy').format(_selectedDate!)
                  : null,
              _selectDate,
            ),
            _buildFilterOption(
              Icons.calendar_view_month,
              'Month',
              _selectedMonth != null
                  ? DateFormat('MMM yyyy').format(_selectedMonth!)
                  : null,
              _selectMonth,
            ),
            _buildFilterOption(
              Icons.event_note,
              'Year',
              _selectedYear != null
                  ? DateFormat('yyyy').format(_selectedYear!)
                  : null,
              _selectYear,
            ),
            const Divider(),
            _buildFilterOption(Icons.all_inclusive, 'All Records', null, () {
              setState(() {
                _filterType = 'all';
                _selectedDate = null;
                _selectedMonth = null;
                _selectedYear = null;
              });
              Navigator.pop(context);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(
    IconData icon,
    String title,
    String? value,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      trailing: value != null
          ? Chip(
              label: Text(value, style: const TextStyle(fontSize: 12)),
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            )
          : null,
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedMonth = null;
        _selectedYear = null;
        _filterType = 'date';
      });
      Navigator.pop(context);
    }
  }

  Future<void> _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
        _selectedDate = null;
        _selectedYear = null;
        _filterType = 'month';
      });
      Navigator.pop(context);
    }
  }

  Future<void> _selectYear() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null) {
      setState(() {
        _selectedYear = DateTime(picked.year);
        _selectedDate = null;
        _selectedMonth = null;
        _filterType = 'year';
      });
      Navigator.pop(context);
    }
  }

  void _clearFilters() {
    setState(() {
      _filterType = 'all';
      _selectedDate = null;
      _selectedMonth = null;
      _selectedYear = null;
    });
  }

  List<WorkerSummary> _processWorkerSummary(List<QueryDocumentSnapshot> docs) {
    final Map<String, WorkerSummary> workerMap = {};

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final workers = data['workers'] as Map<String, dynamic>? ?? {};
      final day = data['day'] ?? '';

      workers.forEach((name, workerData) {
        if (!workerMap.containsKey(name)) {
          workerMap[name] = WorkerSummary(
            name: name,
            designation: workerData['designation'] ?? 'Unknown',
            dailySalary:
                int.tryParse(workerData['salary']?.toString() ?? '0') ?? 0,
          );
        }

        final attendance = (workerData['attendance'] ?? '')
            .toString()
            .toLowerCase();

        switch (attendance) {
          case 'present':
            workerMap[name]!.daysPresent++;
            break;
          case 'absent':
            workerMap[name]!.daysAbsent++;
            break;
          case 'overtime':
            workerMap[name]!.daysOvertime++;
            break;
          case 'halfday':
            workerMap[name]!.daysHalfday++;
            break;
        }

        workerMap[name]!.attendanceDays.add(day);
      });
    }

    return workerMap.values.toList();
  }

  OverallStatistics _calculateOverallStatistics(
    List<QueryDocumentSnapshot> docs,
  ) {
    int totalWorkers = 0;
    int totalPresent = 0;
    int totalAbsent = 0;
    int totalOvertime = 0;
    int totalHalfday = 0;
    int totalEarnings = 0;

    final Set<String> uniqueWorkers = <String>{};

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final workers = data['workers'] as Map<String, dynamic>? ?? {};

      workers.forEach((name, workerData) {
        uniqueWorkers.add(name);

        final attendance = (workerData['attendance'] ?? '')
            .toString()
            .toLowerCase();
        final salary =
            int.tryParse(workerData['salary']?.toString() ?? '0') ?? 0;

        switch (attendance) {
          case 'present':
            totalPresent++;
            totalEarnings += salary;
            break;
          case 'absent':
            totalAbsent++;
            break;
          case 'overtime':
            totalOvertime++;
            totalEarnings += (salary * 1.5)
                .round(); // Overtime typically pays more
            break;
          case 'halfday':
            totalHalfday++;
            totalEarnings += (salary * 0.5).round(); // Half day pays half
            break;
        }
      });
    }

    totalWorkers = uniqueWorkers.length;

    return OverallStatistics(
      totalWorkers: totalWorkers,
      totalPresent: totalPresent,
      totalAbsent: totalAbsent,
      totalOvertime: totalOvertime,
      totalHalfday: totalHalfday,
      totalEarnings: totalEarnings,
    );
  }

  Widget _buildWorkerSummaryCard(WorkerSummary worker, int index) {
    final totalDays =
        worker.daysPresent +
        worker.daysAbsent +
        worker.daysOvertime +
        worker.daysHalfday;
    final totalEarnings =
        (worker.daysPresent * worker.dailySalary) +
        (worker.daysOvertime * (worker.dailySalary * 1.5).round()) +
        (worker.daysHalfday * (worker.dailySalary * 0.5).round());

    // Alternate background color for cards
    final backgroundColor = index % 2 == 0 ? Colors.white : Colors.grey[50];

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  child: Text(
                    worker.name.isNotEmpty ? worker.name[0].toUpperCase() : '?',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        worker.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        worker.designation,
                        style: const TextStyle(fontSize: 14, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹$totalEarnings',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.greenAccent,
                      ),
                    ),
                    Text(
                      '$totalDays days',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Attendance Statistics
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAttendanceChip(
                  'Present',
                  worker.daysPresent,
                  Colors.green,
                ),
                _buildAttendanceChip('Absent', worker.daysAbsent, Colors.red),
                _buildAttendanceChip(
                  'Overtime',
                  worker.daysOvertime,
                  Colors.orange,
                ),
                _buildAttendanceChip(
                  'Half Day',
                  worker.daysHalfday,
                  Colors.amber,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceChip(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

class WorkerSummary {
  final String name;
  final String designation;
  final int dailySalary;
  int daysPresent = 0;
  int daysAbsent = 0;
  int daysOvertime = 0;
  int daysHalfday = 0;
  final List<String> attendanceDays = [];

  WorkerSummary({
    required this.name,
    required this.designation,
    required this.dailySalary,
  });
}

class OverallStatistics {
  final int totalWorkers;
  final int totalPresent;
  final int totalAbsent;
  final int totalOvertime;
  final int totalHalfday;
  final int totalEarnings;

  OverallStatistics({
    required this.totalWorkers,
    required this.totalPresent,
    required this.totalAbsent,
    required this.totalOvertime,
    required this.totalHalfday,
    required this.totalEarnings,
  });
}
