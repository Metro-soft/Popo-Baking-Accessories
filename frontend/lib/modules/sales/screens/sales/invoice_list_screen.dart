import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_service.dart';

class SalesInvoicesScreen extends StatefulWidget {
  const SalesInvoicesScreen({super.key});

  @override
  State<SalesInvoicesScreen> createState() => _SalesInvoicesScreenState();
}

class _SalesInvoicesScreenState extends State<SalesInvoicesScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _invoices = [];

  // Date Filter
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    try {
      // In a real app, we'd pass filters to the API
      // For now, we'll fetch recent sales and filter client-side or assume API returns all
      // We might need to add a specific endpoint for 'invoices' or use 'sales/history'
      // effectively mapping 'orders' to 'invoices'
      final data = await _apiService.getSalesHistory();
      setState(() => _invoices = data);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Invoices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2023),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _dateRange = picked);
                _loadInvoices(); // Ideally pass picked range to API
              }
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadInvoices),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filter Summary
                if (_dateRange != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Chip(
                      label: Text(
                        '${DateFormat('MMM d').format(_dateRange!.start)} - ${DateFormat('MMM d').format(_dateRange!.end)}',
                      ),
                      onDeleted: () {
                        setState(() => _dateRange = null);
                        _loadInvoices();
                      },
                    ),
                  ),

                // Invoice List
                Expanded(
                  child: ListView.separated(
                    itemCount: _invoices.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final invoice = _invoices[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: invoice['status'] == 'completed'
                              ? Colors.green[100]
                              : Colors.orange[100],
                          child: Icon(
                            invoice['status'] == 'completed'
                                ? Icons.check
                                : Icons.hourglass_empty,
                            color: invoice['status'] == 'completed'
                                ? Colors.green
                                : Colors.orange,
                            size: 20,
                          ),
                        ),
                        title: Text('Invoice #${invoice['id']}'),
                        subtitle: Text(
                          '${DateFormat('MMM d, yyyy HH:mm').format(DateTime.parse(invoice['created_at']))}\nCustomer: ${invoice['customer_name'] ?? 'Walk-in'}',
                        ),
                        isThreeLine: true,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'KES ${invoice['total_amount']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              invoice['payment_method'] ?? 'Cash',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          // TODO: Show Invoice Detail / Print View
                          _showInvoiceDetail(invoice);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navigate to POS for new sale? Or a dedicated Invoice Form?
          // Usually Invoices are created via POS or a specific B2B Order Form.
          // For now, redirect to POS.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Create Invoice via POS "Sales Orders" menu'),
            ),
          );
        },
        label: const Text('New Invoice'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  void _showInvoiceDetail(Map<String, dynamic> invoice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        builder: (_, scrollController) => Container(
          color: Colors.white,
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: [
              Text(
                'Invoice #${invoice['id']}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(),
              ListTile(
                title: const Text('Date'),
                trailing: Text(
                  DateFormat(
                    'yyyy-MM-dd HH:mm',
                  ).format(DateTime.parse(invoice['created_at'])),
                ),
              ),
              ListTile(
                title: const Text('Customer'),
                trailing: Text(invoice['customer_name'] ?? 'Walk-in'),
              ),
              ListTile(
                title: const Text('Status'),
                trailing: Chip(label: Text(invoice['status'])),
              ),
              const Divider(),
              const Text(
                'Items',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              // Ideally fetch items if not included in summary list
              // Assuming API might need to fetch details:
              FutureBuilder(
                future: _apiService.getTransactionDetails(invoice['id']),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return const LinearProgressIndicator();
                  if (snapshot.hasError)
                    return Text('Error loading items: ${snapshot.error}');

                  final details = snapshot.data as Map<String, dynamic>;
                  final items = details['items'] as List<dynamic>;

                  return Column(
                    children: items
                        .map(
                          (item) => ListTile(
                            title: Text(item['product_name']),
                            subtitle: Text(
                              '${item['quantity']} x ${item['unit_price']}',
                            ),
                            trailing: Text('KES ${item['subtotal']}'),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'KES ${invoice['total_amount']}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.print),
                      label: const Text('Print'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.share),
                      label: const Text('Share PDF'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
