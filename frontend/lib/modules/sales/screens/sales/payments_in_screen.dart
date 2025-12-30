import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import 'package:intl/intl.dart';

class PaymentsInScreen extends StatefulWidget {
  const PaymentsInScreen({super.key});

  @override
  State<PaymentsInScreen> createState() => _PaymentsInScreenState();
}

class _PaymentsInScreenState extends State<PaymentsInScreen> {
  final ApiService _apiService = ApiService();
  final NumberFormat _currency = NumberFormat.currency(
    symbol: 'KES ',
    decimalDigits: 0,
  );
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy HH:mm');

  List<dynamic> _allPayments = [];
  List<dynamic> _filteredPayments = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.getPaymentsIn();
      setState(() {
        _allPayments = data;
        _filteredPayments = data;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading payments: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filter(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredPayments = _allPayments;
      } else {
        final q = query.toLowerCase();
        _filteredPayments = _allPayments.where((p) {
          final customer = (p['customer_name'] ?? '').toString().toLowerCase();
          final notes = (p['notes'] ?? '').toString().toLowerCase();
          final method = (p['method'] ?? '').toString().toLowerCase();
          return customer.contains(q) ||
              notes.contains(q) ||
              method.contains(q);
        }).toList();
      }
    });
  }

  double get _totalReceived {
    return _filteredPayments.fold(0.0, (sum, item) {
      return sum + (double.tryParse(item['amount'].toString()) ?? 0.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payments In',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFA01B2D),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Record of all money received from customers (POS + Debt Payments)',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Card(
                  color: Colors.green[50],
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.green[100]!),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'TOTAL RECEIVED',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green[900],
                          ),
                        ),
                        Text(
                          _currency.format(_totalReceived),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[900],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadPayments,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search Payments (Customer, Method, Reference)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filter,
            ),
          ),
          // Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPayments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No payment records found',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          Colors.grey[100],
                        ),
                        columns: const [
                          DataColumn(label: Text('Date & Time')),
                          DataColumn(label: Text('Customer')),
                          DataColumn(label: Text('Method')),
                          DataColumn(label: Text('Notes / Reference')),
                          DataColumn(
                            label: Text('Amount', textAlign: TextAlign.right),
                          ),
                        ],
                        rows: _filteredPayments.map((p) {
                          final amount =
                              double.tryParse(p['amount'].toString()) ?? 0.0;
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  _dateFormat.format(
                                    DateTime.parse(p['payment_date']),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  p['customer_name'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
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
                                    color: _getMethodColor(
                                      p['method'],
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: _getMethodColor(
                                        p['method'],
                                      ).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    (p['method'] ?? 'Cash')
                                        .toString()
                                        .toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _getMethodColor(p['method']),
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(Text(p['notes'] ?? '-')),
                              DataCell(
                                Text(
                                  _currency.format(amount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Color _getMethodColor(String? method) {
    if (method == null) return Colors.black;
    final m = method.toLowerCase();
    if (m == 'cash') return Colors.green;
    if (m == 'mpesa') return Colors.green[800]!;
    if (m == 'bank') return Colors.blue;
    return Colors.grey[800]!;
  }
}
