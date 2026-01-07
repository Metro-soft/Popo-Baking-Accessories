import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_service.dart';
import '../../sales/widgets/invoice_summary_card.dart';
import '../widgets/purchase_bill_data_table.dart';
import '../../inventory/screens/receive_stock_screen.dart';

class PurchaseBillsScreen extends StatefulWidget {
  const PurchaseBillsScreen({super.key});

  @override
  State<PurchaseBillsScreen> createState() => _PurchaseBillsScreenState();
}

class _PurchaseBillsScreenState extends State<PurchaseBillsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _allBills = [];
  List<dynamic> _filteredBills = [];

  // Filters
  DateTimeRange? _dateRange;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  Future<void> _loadBills() async {
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.getPurchaseBills();
      // Sort by date descending with safe parsing
      data.sort((a, b) {
        final dateA =
            DateTime.tryParse(a['created_at']?.toString() ?? '') ??
            DateTime.now();
        final dateB =
            DateTime.tryParse(b['created_at']?.toString() ?? '') ??
            DateTime.now();
        return dateB.compareTo(dateA);
      });
      _allBills = data;
      _applyFilters();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading bills: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredBills = _allBills.where((bill) {
        // 1. Date Filter
        if (_dateRange != null) {
          final dateStr = bill['created_at']?.toString();
          if (dateStr == null) return false;
          final date = DateTime.tryParse(dateStr) ?? DateTime.now();

          if (date.isBefore(_dateRange!.start) ||
              date.isAfter(_dateRange!.end.add(const Duration(days: 1)))) {
            return false;
          }
        }

        // 2. Status Filter
        if (_statusFilter != null) {
          final status = bill['payment_status'] ?? 'unpaid';
          if (_statusFilter == 'paid' && status != 'paid') return false;
          // If filter is 'unpaid', show 'unpaid' AND 'partial'
          if (_statusFilter == 'unpaid' && status == 'paid') return false;
        }

        return true;
      }).toList();
    });
  }

  void _onFilterTap(String? status) {
    setState(() {
      _statusFilter = (_statusFilter == status) ? null : status;
    });
    _applyFilters();
  }

  Map<String, double> _calculateMetrics() {
    double totalPaid = 0;
    double totalUnpaid = 0;
    double grandTotal = 0;

    for (var bill in _allBills) {
      final total = double.tryParse(bill['total_amount'].toString()) ?? 0;
      final paid = double.tryParse(bill['total_paid'].toString()) ?? 0;
      final balance = total - paid;

      totalPaid += paid;
      totalUnpaid += balance;
      grandTotal += total;
    }

    return {'paid': totalPaid, 'unpaid': totalUnpaid, 'total': grandTotal};
  }

  void _showPaymentDialog(Map<String, dynamic> bill) {
    final amountCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    String method = 'cash';
    final balance =
        (double.tryParse(bill['total_amount'].toString()) ?? 0) -
        (double.tryParse(bill['total_paid'].toString()) ?? 0);

    amountCtrl.text = balance.toStringAsFixed(2);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Pay Bill #${bill['id']}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Supplier: ${bill['supplier_name'] ?? 'Unknown'}'),
                Text('Outstanding: KES${balance.toStringAsFixed(2)}'),
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                    prefixText: 'KES ',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: method,
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(
                      value: 'bank',
                      child: Text('Bank Transfer'),
                    ),
                    DropdownMenuItem(value: 'mpesa', child: Text('M-Pesa')),
                  ],
                  onChanged: (v) => setState(() => method = v!),
                  decoration: const InputDecoration(labelText: 'Method'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: refCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Reference (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(amountCtrl.text);
                  if (amount == null || amount <= 0) return;

                  Navigator.pop(ctx);
                  _submitPayment(bill['id'], amount, method, refCtrl.text);
                },
                child: const Text('Record Payment'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submitPayment(
    int poId,
    double amount,
    String method,
    String ref,
  ) async {
    setState(() => _isLoading = true);
    try {
      await _apiService.recordSupplierPayment({
        'poId': poId,
        'amount': amount,
        'method': method,
        'reference': ref,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment Recorded Successfully')),
        );
      }
      _loadBills();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Payment Failed: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _calculateMetrics();
    final formatter = NumberFormat('#,##0.00');

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Purchase Bills',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            onPressed: _loadBills,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Summary Cards ---
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFEEEEEE)),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Row(
                    children: [
                      InvoiceSummaryCard(
                        title: 'Paid',
                        value: 'KES ${formatter.format(metrics['paid'])}',
                        icon: Icons.check_circle_outline,
                        color: Colors.green,
                        isSelected: _statusFilter == 'paid',
                        onTap: () => _onFilterTap('paid'),
                      ),
                      InvoiceSummaryCard(
                        title: 'Unpaid / Debt',
                        value: 'KES ${formatter.format(metrics['unpaid'])}',
                        icon: Icons.pending_actions,
                        color: Colors.orange,
                        isSelected: _statusFilter == 'unpaid',
                        onTap: () => _onFilterTap('unpaid'),
                      ),
                      InvoiceSummaryCard(
                        title: 'Total Purchases',
                        value: 'KES ${formatter.format(metrics['total'])}',
                        icon: Icons.shopping_basket_outlined,
                        color: Colors.blue, // Blue for Purchases
                        isSelected: false,
                        onTap: () => _onFilterTap(null),
                      ),
                    ],
                  ),
                ),

                // --- Filter & Action Bar ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Row(
                    children: [
                      Text(
                        _dateRange != null
                            ? 'From ${DateFormat('MMM d').format(_dateRange!.start)} to ${DateFormat('MMM d').format(_dateRange!.end)}'
                            : 'All Bills',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      if (_dateRange != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: InkWell(
                            onTap: () {
                              setState(() => _dateRange = null);
                              _loadBills();
                            },
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                      const SizedBox(width: 16),
                      // Date Picker Button (Small)
                      IconButton(
                        icon: const Icon(Icons.calendar_today, size: 20),
                        color: Colors.grey[600],
                        onPressed: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2023),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => _dateRange = picked);
                            _loadBills();
                          }
                        },
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ReceiveStockScreen(),
                            ),
                          ).then((_) => _loadBills());
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('New Bill (Receive Stock)'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                        ),
                      ),
                    ],
                  ),
                ),

                // --- Data Table ---
                Expanded(
                  child: PurchaseBillDataTable(
                    bills: _filteredBills,
                    onPay: _showPaymentDialog,
                  ),
                ),
              ],
            ),
    );
  }
}
