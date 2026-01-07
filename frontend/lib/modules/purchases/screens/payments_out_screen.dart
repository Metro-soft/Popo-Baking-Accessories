import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_service.dart';
import '../../sales/widgets/invoice_summary_card.dart';

class PaymentsOutScreen extends StatefulWidget {
  const PaymentsOutScreen({super.key});

  @override
  State<PaymentsOutScreen> createState() => _PaymentsOutScreenState();
}

class _PaymentsOutScreenState extends State<PaymentsOutScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _allPayments = [];
  List<dynamic> _filteredPayments = [];

  // Filters
  DateTimeRange? _dateRange;
  String? _searchQuery;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.getPaymentsOut();
      // Sort by date descending
      data.sort((a, b) {
        final dateA =
            DateTime.tryParse(a['payment_date']?.toString() ?? '') ??
            DateTime.now();
        final dateB =
            DateTime.tryParse(b['payment_date']?.toString() ?? '') ??
            DateTime.now();
        return dateB.compareTo(dateA);
      });
      _allPayments = data;
      _applyFilters();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading payments: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredPayments = _allPayments.where((payment) {
        // 1. Date Filter
        if (_dateRange != null) {
          final dateStr = payment['payment_date']?.toString();
          if (dateStr == null) return false;
          final date = DateTime.tryParse(dateStr) ?? DateTime.now();
          if (date.isBefore(_dateRange!.start) ||
              date.isAfter(_dateRange!.end.add(const Duration(days: 1)))) {
            return false;
          }
        }

        // 2. Search Filter (Supplier Name or Reference)
        if (_searchQuery != null && _searchQuery!.isNotEmpty) {
          final query = _searchQuery!.toLowerCase();
          final supplier = (payment['supplier_name'] ?? '')
              .toString()
              .toLowerCase();
          final reference = (payment['reference'] ?? '')
              .toString()
              .toLowerCase();
          final method = (payment['method'] ?? '').toString().toLowerCase();

          if (!supplier.contains(query) &&
              !reference.contains(query) &&
              !method.contains(query)) {
            return false;
          }
        }

        return true;
      }).toList();
    });
  }

  Map<String, double> _calculateMetrics() {
    double totalPaid = 0;
    int count = 0;

    for (var p in _filteredPayments) {
      final amount = double.tryParse(p['amount'].toString()) ?? 0;
      totalPaid += amount;
      count++;
    }

    return {'total': totalPaid, 'count': count.toDouble()};
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.deepPurple),
      );
    }

    final metrics = _calculateMetrics();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildSummaryCards(metrics),
          const SizedBox(height: 24),
          _buildToolbar(),
          const SizedBox(height: 16),
          Expanded(child: _buildDataTable()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payments Out',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'History of payments made to suppliers',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(Map<String, double> metrics) {
    return Row(
      children: [
        Expanded(
          child: InvoiceSummaryCard(
            title: 'Total Payments',
            value: 'KES ${metrics['total']!.toStringAsFixed(2)}',
            icon: Icons.money_off,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: InvoiceSummaryCard(
            title: 'Transactions',
            value: '${metrics['count']!.toInt()}',
            icon: Icons.receipt_long,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: Container()), // Spacer for alignment
      ],
    );
  }

  Widget _buildToolbar() {
    return Row(
      children: [
        // Search
        Expanded(
          flex: 2,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search Supplier, Ref...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (val) {
              setState(() => _searchQuery = val);
              _applyFilters();
            },
          ),
        ),
        const SizedBox(width: 16),
        // Date Filter
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              initialDateRange: _dateRange,
            );
            if (picked != null) {
              setState(() => _dateRange = picked);
              _applyFilters();
            }
          },
          icon: const Icon(Icons.calendar_today, size: 18),
          label: Text(
            _dateRange == null
                ? 'Filter Date'
                : '${DateFormat('MMM dd').format(_dateRange!.start)} - ${DateFormat('MMM dd').format(_dateRange!.end)}',
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (_dateRange != null)
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: () {
              setState(() => _dateRange = null);
              _applyFilters();
            },
          ),
      ],
    );
  }

  Widget _buildDataTable() {
    if (_filteredPayments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No payments found',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SizedBox(
            width: double.infinity,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
              dividerThickness: 1,
              horizontalMargin: 24,
              columnSpacing: 24,
              columns: const [
                DataColumn(
                  label: Text(
                    'Date',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Supplier',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Reference',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Method',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Amount',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              rows: _filteredPayments.map((payment) {
                final date =
                    DateTime.tryParse(
                      payment['payment_date']?.toString() ?? '',
                    ) ??
                    DateTime.now();
                final amount =
                    double.tryParse(payment['amount'].toString()) ?? 0;

                return DataRow(
                  cells: [
                    DataCell(Text(DateFormat('MMM dd, yyyy').format(date))),
                    DataCell(
                      Text(
                        payment['supplier_name'] ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    DataCell(
                      Text(
                        payment['reference'] ?? '-',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          (payment['method'] ?? '-').toString().toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        'KES ${amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
