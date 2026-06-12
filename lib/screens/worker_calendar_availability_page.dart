import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_cst/services/firestore_service.dart';
import 'package:demo_cst/widgets/glass_scaffold.dart';
import 'package:demo_cst/widgets/glass_card.dart';

class WorkerCalendarAvailabilityPage extends StatefulWidget {
  final String workerId;
  final String workerName;
  final String workerDesignation;
  final String siteId;

  const WorkerCalendarAvailabilityPage({
    super.key,
    required this.workerId,
    required this.workerName,
    required this.workerDesignation,
    required this.siteId,
  });

  @override
  State<WorkerCalendarAvailabilityPage> createState() =>
      _WorkerCalendarAvailabilityPageState();
}

class _WorkerCalendarAvailabilityPageState
    extends State<WorkerCalendarAvailabilityPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<String, dynamic> _attendanceData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadMonthlyAttendance(_focusedDay);
  }

  Future<void> _loadMonthlyAttendance(DateTime monthDate) async {
    setState(() => _isLoading = true);
    final monthStr = DateFormat('MM-yyyy').format(monthDate);

    try {
      final snapshot = await FirestoreService.getCollection(
        'workersAttendance',
      ).where('month', isEqualTo: monthStr).get();

      Map<String, dynamic> attendance = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final workersMap = data['workers'] as Map<String, dynamic>? ?? {};

        if (workersMap.containsKey(widget.workerName) ||
            workersMap.containsKey(widget.workerId)) {
          final workerInfo =
              workersMap[widget.workerName] ?? workersMap[widget.workerId];

          String? formattedDate;

          // Priority 1: Use 'day' and 'month' fields (e.g., day: "31", month: "03-2026")
          final dayField = data['day']?.toString();
          final monthField = data['month']?.toString();

          if (dayField != null && monthField != null) {
            final monthParts = monthField.split('-');
            if (monthParts.length == 2) {
              formattedDate =
                  '${monthParts[1]}-${monthParts[0]}-${dayField.padLeft(2, '0')}';
            }
          }

          // Priority 2: Use legacy 'Day' field (dd/MM/yyyy)
          if (formattedDate == null) {
            final legacyDay = data['Day']?.toString();
            if (legacyDay != null) {
              final parts = legacyDay.split('/');
              if (parts.length == 3) {
                formattedDate = '${parts[2]}-${parts[1]}-${parts[0]}';
              }
            }
          }

          if (formattedDate != null) {
            attendance[formattedDate] = {
              'status': workerInfo['attendance'] ?? 'None',
              'salaryPerDay': workerInfo['salary'] ?? '0',
              'markedAt': data['updatedAt'],
              'site': data['site'],
            };
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _attendanceData = attendance;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading attendance: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Colors.greenAccent;
      case 'absent':
        return Colors.redAccent;
      case 'half day':
        return Colors.orangeAccent;
      case 'overtime':
        return Colors.purpleAccent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDay!);
    final dayDetails =
        _attendanceData[selectedDateStr] as Map<String, dynamic>?;

    return GlassScaffold(
      title: 'Worker Schedule',
      onBack: () => Navigator.pop(context),
      body: Column(
        children: [
          _buildWorkerHeader(colorScheme),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildCalendar(colorScheme),
                  const SizedBox(height: 20),
                  _buildDayDetails(dayDetails, colorScheme),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerHeader(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              widget.workerName[0],
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.workerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.workerDesignation,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Site: ${widget.siteId}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(ColorScheme colorScheme) {
    return GlassCard(
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
          _loadMonthlyAttendance(focusedDay);
        },
        calendarStyle: CalendarStyle(
          todayTextStyle: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
          todayDecoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: colorScheme.primary,
            shape: BoxShape.circle,
          ),
          markerDecoration: const BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
          ),
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
          leftChevronIcon: Icon(Icons.chevron_left, color: colorScheme.primary),
          rightChevronIcon: Icon(
            Icons.chevron_right,
            color: colorScheme.primary,
          ),
        ),
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focusedDay) =>
              _buildHighlightedDay(day, colorScheme),
          holidayBuilder: (context, day, focusedDay) =>
              _buildHighlightedDay(day, colorScheme),
          outsideBuilder: (context, day, focusedDay) =>
              _buildHighlightedDay(day, colorScheme, isOutside: true),
          markerBuilder: (context, day, events) {
            final dateStr = DateFormat('yyyy-MM-dd').format(day);
            if (_attendanceData.containsKey(dateStr)) {
              final status =
                  _attendanceData[dateStr]['status'] as String? ?? '';
              return Positioned(
                bottom: 4,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget? _buildHighlightedDay(
    DateTime day,
    ColorScheme colorScheme, {
    bool isOutside = false,
  }) {
    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    final hasStatus = _attendanceData.containsKey(dateStr);

    if (hasStatus) {
      final status = _attendanceData[dateStr]['status'] as String? ?? '';
      final color = _getStatusColor(status);
      final isSelected = isSameDay(_selectedDay, day);
      final isToday = isSameDay(DateTime.now(), day);

      return Center(
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary
                : isToday
                ? colorScheme.primary.withOpacity(0.15)
                : color.withOpacity(0.25),
            shape: BoxShape.circle,
            boxShadow: [
              if (hasStatus && !isOutside && !isSelected)
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              if (isSelected)
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
            ],
            border: Border.all(
              color: isSelected
                  ? Colors.white
                  : isToday
                  ? colorScheme.primary.withOpacity(0.5)
                  : color.withOpacity(isOutside ? 0.2 : 0.6),
              width: isSelected || isToday ? 2 : 1.5,
            ),
          ),
          child: Center(
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontWeight: hasStatus || isToday
                    ? FontWeight.bold
                    : FontWeight.normal,
                fontSize: isSelected ? 15 : 14,
                color: isSelected
                    ? Colors.white
                    : isToday
                    ? colorScheme.primary
                    : isOutside
                    ? Colors.grey.withOpacity(0.5)
                    : const Color(0xFF1E293B),
              ),
            ),
          ),
        ),
      );
    }
    return null;
  }

  Widget _buildDayDetails(
    Map<String, dynamic>? details,
    ColorScheme colorScheme,
  ) {
    final status = details?['status'] as String? ?? 'None';
    final salary = details?['salaryPerDay'] ?? 0;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMM dd, yyyy').format(_selectedDay!),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getStatusColor(status).withOpacity(0.5),
                  ),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: _getStatusColor(status).withOpacity(0.8),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          _buildDetailRow(
            Icons.payments_outlined,
            'Daily Earnings',
            '₹$salary',
            colorScheme.primary,
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            Icons.access_time_rounded,
            'Marked At',
            details?['markedAt'] != null
                ? DateFormat(
                    'hh:mm a',
                  ).format((details!['markedAt'] as Timestamp).toDate())
                : 'N/A',
            colorScheme.secondary,
          ),
          if (details != null && details['workDescription'] != null) ...[
            const SizedBox(height: 16),
            _buildDetailRow(
              Icons.description_outlined,
              'Work Details',
              details['workDescription'],
              Colors.blueGrey,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
