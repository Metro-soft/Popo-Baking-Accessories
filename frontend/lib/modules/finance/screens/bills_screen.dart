import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/api_service.dart';
import '../widgets/new_bill_dialog.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  final ApiService _api = ApiService();

  List<dynamic> _bills = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final bills = await _api.getBills();

      if (mounted) {
        setState(() {
          _bills = bills;

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading bills: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Recurring Bills',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildDashboardView(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBillModal,
        backgroundColor: const Color(0xFFA01B2D),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Bill', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildDashboardView() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_bills.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No recurring bills set up.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Group bills
    final overdue = _bills.where((b) {
      final due = DateTime.parse(b['next_due_date']);
      final now = DateTime.now();
      return due.isBefore(DateTime(now.year, now.month, now.day));
    }).toList();

    final dueSoon = _bills.where((b) {
      final due = DateTime.parse(b['next_due_date']);
      final now = DateTime.now();
      final diff = due.difference(now).inDays;
      return diff >= 0 && diff <= 7;
    }).toList();

    final upcoming = _bills.where((b) {
      final due = DateTime.parse(b['next_due_date']);
      final now = DateTime.now();
      final diff = due.difference(now).inDays;
      return diff > 7;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (overdue.isNotEmpty) ...[
              _buildSectionHeader('Overdue', Colors.red),
              ...overdue.map(_buildBillCard),
              const SizedBox(height: 24),
            ],
            if (dueSoon.isNotEmpty) ...[
              _buildSectionHeader('Due This Week', Colors.orange),
              ...dueSoon.map(_buildBillCard),
              const SizedBox(height: 24),
            ],
            if (upcoming.isNotEmpty) ...[
              _buildSectionHeader('Upcoming', Colors.green),
              ...upcoming.map(_buildBillCard),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            color: color,
            margin: const EdgeInsets.only(right: 8),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillCard(dynamic bill) {
    final amount = double.parse(bill['amount']);
    final dueDate = DateTime.parse(bill['next_due_date']);
    final daysLeft = dueDate.difference(DateTime.now()).inDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.receipt, color: Colors.blue),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Due: ${DateFormat('MMM dd').format(dueDate)} (${daysLeft < 0 ? '${daysLeft.abs()} days overdue' : '$daysLeft days left'})',
                    style: TextStyle(
                      fontSize: 12,
                      color: daysLeft < 0
                          ? Colors.red
                          : (daysLeft <= 7 ? Colors.orange : Colors.grey[600]),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'KES ${NumberFormat('#,##0').format(amount)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                if (bill['payment_instructions'] != null &&
                    bill['payment_instructions'].isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.info_outline, size: 16),
                    label: const Text(
                      'Details',
                      style: TextStyle(fontSize: 12),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('Instructions for ${bill['name']}'),
                          content: Text(bill['payment_instructions']),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 24),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                const SizedBox(height: 4),
                ElevatedButton(
                  onPressed: () => _showPayDialog(bill),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFA01B2D),
                    side: const BorderSide(color: Color(0xFFA01B2D)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 32),
                  ),
                  child: const Text('Pay Now'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddBillModal() async {
    final result = await showDialog(
      context: context,
      builder: (ctx) => const NewBillDialog(),
    );

    if (result == true) {
      _loadData(); // Refresh list
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bill created successfully')),
      );
    }
  }

  void _showPayDialog(dynamic bill) {
    // Pre-fill
    final amountCtrl = TextEditingController(text: bill['amount']);
    String paymentMethod = 'Bank Transfer';
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pay: ${bill['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: amountCtrl,
              decoration: const InputDecoration(labelText: 'Amount Paid'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: paymentMethod,
              decoration: const InputDecoration(labelText: 'Method'),
              items: [
                'Cash',
                'M-Pesa',
                'Bank Transfer',
                'Cheque',
              ].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (val) => paymentMethod = val!,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              try {
                await _api.payBill(bill['id'], {
                  'amount': double.parse(amountCtrl.text),
                  'payment_method': paymentMethod,
                  'date': selectedDate.toIso8601String(),
                });
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _loadData();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Bill Paid successfully! Next due date updated.',
                    ),
                  ),
                );
              } catch (e) {
                if (!ctx.mounted) return;
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text(
              'Confirm Payment',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
