import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DashboardCalendarWidget extends StatefulWidget {
  final List<DateTime> payrollDates;
  final List<DateTime> billDates;
  final Function(DateTime) onDateSelected;
  final Function(DateTime)? onMonthChanged;

  const DashboardCalendarWidget({
    super.key,
    required this.payrollDates,
    required this.billDates,
    required this.onDateSelected,
    this.onMonthChanged,
  });

  @override
  State<DashboardCalendarWidget> createState() =>
      _DashboardCalendarWidgetState();
}

class _DashboardCalendarWidgetState extends State<DashboardCalendarWidget> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 8),
          _buildDaysOfWeek(),
          const SizedBox(height: 4),
          _buildCalendarGrid(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          DateFormat('MMMM yyyy').format(_focusedDay),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                setState(() {
                  _focusedDay = DateTime(
                    _focusedDay.year,
                    _focusedDay.month - 1,
                  );
                });
                widget.onMonthChanged?.call(_focusedDay);
              },
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                setState(() {
                  _focusedDay = DateTime(
                    _focusedDay.year,
                    _focusedDay.month + 1,
                  );
                });
                widget.onMonthChanged?.call(_focusedDay);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDaysOfWeek() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: days
          .map(
            (day) => Expanded(
              child: Center(
                child: Text(
                  day,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = DateUtils.getDaysInMonth(
      _focusedDay.year,
      _focusedDay.month,
    );
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final firstWeekday = firstDayOfMonth.weekday;
    final offset = firstWeekday - 1;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: daysInMonth + offset,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 2, // Compact spacing
        crossAxisSpacing: 2, // Compact spacing
        childAspectRatio: 1.2, // Make cells shorter height-wise
      ),
      itemBuilder: (context, index) {
        if (index < offset) return const SizedBox();
        final day = index - offset + 1;
        final date = DateTime(_focusedDay.year, _focusedDay.month, day);
        return _buildDayCell(date);
      },
    );
  }

  Widget _buildDayCell(DateTime date) {
    final isSelected = DateUtils.isSameDay(date, _selectedDay);
    final isToday = DateUtils.isSameDay(date, DateTime.now());

    // Check events
    final hasPayroll = widget.payrollDates.any(
      (d) => DateUtils.isSameDay(d, date),
    );
    final hasBill = widget.billDates.any((d) => DateUtils.isSameDay(d, date));

    return GestureDetector(
      onTap: () {
        setState(() => _selectedDay = date);
        widget.onDateSelected(date);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFA01B2D)
              : (isToday
                    ? const Color(0xFFA01B2D).withValues(alpha: 0.1)
                    : Colors.transparent),
          borderRadius: BorderRadius.circular(12),
          border: isToday && !isSelected
              ? Border.all(color: const Color(0xFFA01B2D), width: 1)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isToday ? const Color(0xFFA01B2D) : Colors.black87),
                fontWeight: isSelected || isToday
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            if (hasPayroll || hasBill)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (hasBill)
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (hasBill && hasPayroll) const SizedBox(width: 2),
                    if (hasPayroll)
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
