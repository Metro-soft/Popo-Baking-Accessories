import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DashboardChartWidget extends StatelessWidget {
  final List<dynamic>
  monthlyData; // Expected: [{month: 'Jan', expense: 100, payroll: 200}, ...]

  const DashboardChartWidget({super.key, required this.monthlyData});

  double _parseAmount(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.tryParse(value.toString()) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    // If empty or null, show empty state or zeros?
    // Let's default to zeros for current year if completely empty
    final List<dynamic> data = monthlyData.isEmpty
        ? _generateEmptyMonths()
        : monthlyData;

    // Dynamic Max Y
    double maxY = 10000;
    if (data.isNotEmpty) {
      double maxVal = 0;
      for (var item in data) {
        maxVal = ((double.tryParse(item['amount'].toString()) ?? 0));
        if (maxVal > maxY) maxY = maxVal;
      }
      maxY = maxY * 1.2; // Add buffer
    }

    print('📊 CHART DEBUG: Data Length: ${data.length}');
    if (data.isNotEmpty) {
      print('📊 CHART DEBUG: Last Item: ${data.last}');
      print('📊 CHART DEBUG: Calculated maxY: $maxY');
      print(
        '📊 CHART DEBUG: First Bar Amount: ${double.tryParse(data.last['amount'].toString())}',
      );
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Financial Activity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              DropdownButton<String>(
                value: 'Monthly',
                items: const [
                  DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                  DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                ],
                onChanged: (v) {},
                underline: const SizedBox(),
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: Colors.blueGrey,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${(rod.toY / 1000).toStringAsFixed(1)}k',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < data.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              data[value.toInt()]['month'],
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false, // Clean look, no Y axis labels
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20000,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withValues(alpha: 0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: data.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: _parseAmount(item['amount']),
                        color: Colors.blue, // Dynamic color?
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _generateEmptyMonths() {
    final List<Map<String, dynamic>> months = [];
    final now = DateTime.now();
    for (int i = 5; i >= 0; i--) {
      final prevMonth = DateTime(now.year, now.month - i, 1);
      months.add({'month': DateFormat('MMM').format(prevMonth), 'amount': 0.0});
    }
    return months;
  }
}
