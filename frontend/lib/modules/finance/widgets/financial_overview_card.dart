import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FinancialOverviewCard extends StatefulWidget {
  final double payrollTotal;
  final double billsTotal;
  final double expensesTotal;
  final VoidCallback onAddBill;
  final VoidCallback onAddExpense;

  const FinancialOverviewCard({
    super.key,
    required this.payrollTotal,
    required this.billsTotal,
    required this.expensesTotal,
    required this.onAddBill,
    required this.onAddExpense,
  });

  @override
  State<FinancialOverviewCard> createState() => _FinancialOverviewCardState();
}

class _FinancialOverviewCardState extends State<FinancialOverviewCard> {
  String? _hoveredLabel;
  double? _hoveredAmount;

  void _onHover(PointerEvent event) {
    // Basic hit detection based on angle
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    // We need local position relative to the center of the CustomPaint
    // But MouseRegion gives position relative to itself if we wrap CustomPaint directly
    final localPosition = event.localPosition;
    final center = Offset(70, 70); // 140/2

    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;

    // Angle in radians from -pi to pi
    double angle = atan2(dy, dx);
    // Normalize to 0 to 2pi starting from -pi/2 (top)
    // Our drawing starts at -pi/2
    // atan2: 0 is right, pi/2 is down, -pi/2 is top, pi/-pi is left

    // Adjust so 0 is top (-pi/2 in standard)
    double adjustedAngle = angle + pi / 2;
    if (adjustedAngle < 0) adjustedAngle += 2 * pi;

    // Check segments
    double total =
        widget.payrollTotal + widget.billsTotal + widget.expensesTotal;
    if (total == 0) return;

    double currentAngle = 0;

    // Payroll
    double payrollSweep = (widget.payrollTotal / total) * 2 * pi;
    if (adjustedAngle >= currentAngle &&
        adjustedAngle < currentAngle + payrollSweep) {
      setState(() {
        _hoveredLabel = 'Payroll';
        _hoveredAmount = widget.payrollTotal;
      });
      return;
    }
    currentAngle += payrollSweep;

    // Bills
    double billsSweep = (widget.billsTotal / total) * 2 * pi;
    if (adjustedAngle >= currentAngle &&
        adjustedAngle < currentAngle + billsSweep) {
      setState(() {
        _hoveredLabel = 'Bills';
        _hoveredAmount = widget.billsTotal;
      });
      return;
    }
    currentAngle += billsSweep;

    // Expenses
    double expensesSweep = (widget.expensesTotal / total) * 2 * pi;
    if (adjustedAngle >= currentAngle &&
        adjustedAngle < currentAngle + expensesSweep) {
      setState(() {
        _hoveredLabel = 'Expenses';
        _hoveredAmount = widget.expensesTotal;
      });
      return;
    }

    // If outside (e.g. gaps), fallback
    setState(() {
      _hoveredLabel = null;
      _hoveredAmount = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total =
        widget.payrollTotal + widget.billsTotal + widget.expensesTotal;

    return Container(
      height: 300,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Total Outflows',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // The "Clock" / Gauge
                MouseRegion(
                  onHover: _onHover,
                  onExit: (_) => setState(() {
                    _hoveredLabel = null;
                    _hoveredAmount = null;
                  }),
                  child: CustomPaint(
                    size: const Size(140, 140),
                    painter: _GaugePainter(
                      payroll: widget.payrollTotal,
                      bills: widget.billsTotal,
                      expenses: widget.expensesTotal,
                      total: total,
                    ),
                  ),
                ),
                // Center Text
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _hoveredLabel ?? 'Total',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      NumberFormat.compact().format(_hoveredAmount ?? total),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          // Action Buttons
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onAddBill,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.receipt_long, size: 18),
              label: const Text('Record Bill'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onAddExpense,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.attach_money, size: 18),
              label: const Text('Add Expense'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double payroll;
  final double bills;
  final double expenses;
  final double total;

  _GaugePainter({
    required this.payroll,
    required this.bills,
    required this.expenses,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) - 10;
    const strokeWidth = 12.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bgPaint = Paint()
      ..color = Colors.grey.shade100
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw Background Circle
    canvas.drawArc(rect, 0, 2 * pi, false, bgPaint);

    if (total == 0) return;

    // Calculate angles with gaps

    // Normalize logic slightly for gap
    double startAngle = -pi / 2;

    void drawSegment(double value, Color color) {
      if (value <= 0) return;
      final sweepAngle = (value / total) * 2 * pi;
      // Subtract gap from sweep if multiple exist, simplified here:
      // Just draw with whitespace using strokeCap butt and manual gap?
      // Actually, simplest gap is just advancing startAngle extra.

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      // Draw slightly less than full sweep to create visual gap
      final drawAngle = max(0.0, sweepAngle - 0.08);

      canvas.drawArc(rect, startAngle, drawAngle, false, paint);
      startAngle += sweepAngle;
    }

    drawSegment(payroll, const Color(0xFFA01B2D));
    drawSegment(bills, Colors.black87);
    drawSegment(expenses, Colors.orange.shade700);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
