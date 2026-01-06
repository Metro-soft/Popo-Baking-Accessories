import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_service.dart';
import '../../widgets/invoice_summary_card.dart';
import '../../widgets/invoice_data_table.dart';
import '../../services/receipt_service.dart';
import 'pdf_preview_screen.dart';
import '../pos/pos_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/sales_provider.dart';
import '../../../inventory/models/product_model.dart';

class SalesInvoicesScreen extends StatefulWidget {
  const SalesInvoicesScreen({super.key});

  @override
  State<SalesInvoicesScreen> createState() => _SalesInvoicesScreenState();
}

class _SalesInvoicesScreenState extends State<SalesInvoicesScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _allInvoices = [];
  List<dynamic> _filteredInvoices = [];

  // Date Filter
  DateTimeRange? _dateRange;

  // Status Filter (null = All)
  String? _filterStatus; // 'paid', 'unpaid', 'overdue'

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.getSalesHistory();
      // Sort by date descending
      data.sort((a, b) {
        final dateA = DateTime.parse(a['created_at']);
        final dateB = DateTime.parse(b['created_at']);
        return dateB.compareTo(dateA);
      });
      _allInvoices = data;
      _applyFilters();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredInvoices = _allInvoices.where((inv) {
        // 1. Date Filter
        if (_dateRange != null) {
          final date = DateTime.parse(inv['created_at']);
          if (date.isBefore(_dateRange!.start) ||
              date.isAfter(_dateRange!.end.add(const Duration(days: 1)))) {
            return false;
          }
        }

        // 2. Status Filter
        if (_filterStatus != null) {
          // 'paid', 'unpaid', 'overdue'
          final balance = double.tryParse(inv['balance'].toString()) ?? 0;
          // Note: 'overdue' logic requires due_date check, assuming backend might send 'status' or we calc it.
          // For now, let's stick to balance checks.

          if (_filterStatus == 'paid' && balance > 0) return false;
          if (_filterStatus == 'unpaid' && balance <= 0) return false;
        }

        return true;
      }).toList();
    });
  }

  void _onFilterTap(String? status) {
    setState(() {
      _filterStatus = (_filterStatus == status) ? null : status; // Toggle
    });
    _applyFilters();
  }

  // --- Metrics Calculation ---
  Map<String, double> _calculateMetrics() {
    double totalPaid = 0; // Revenue collected
    double totalUnpaid = 0; // Debt
    double grandTotal = 0; // Total Revenue Expected

    for (var inv in _allInvoices) {
      final total = double.tryParse(inv['total_amount'].toString()) ?? 0;
      final balance = double.tryParse(inv['balance'].toString()) ?? 0;
      final paid = total - balance;

      totalPaid += paid;
      totalUnpaid += balance;
      grandTotal += total;
    }

    return {'paid': totalPaid, 'unpaid': totalUnpaid, 'total': grandTotal};
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _calculateMetrics();
    final formatter = NumberFormat('#,##0.00');

    return Scaffold(
      backgroundColor: Colors.grey[50], // Premium background
      appBar: AppBar(
        title: const Text(
          'Sales Invoices',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.black54),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2023),
                lastDate: DateTime.now(),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: Colors.deepPurple,
                        onPrimary: Colors.white,
                        onSurface: Colors.black,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() => _dateRange = picked);
                _loadInvoices();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            onPressed: _loadInvoices,
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
                        isSelected: _filterStatus == 'paid',
                        onTap: () => _onFilterTap('paid'),
                      ),
                      InvoiceSummaryCard(
                        title: 'Unpaid / Debt',
                        value: 'KES ${formatter.format(metrics['unpaid'])}',
                        icon: Icons.pending_actions,
                        color: Colors.orange,
                        isSelected: _filterStatus == 'unpaid',
                        onTap: () => _onFilterTap('unpaid'),
                      ),
                      InvoiceSummaryCard(
                        title: 'Total Sales',
                        value: 'KES ${formatter.format(metrics['total'])}',
                        icon: Icons.monetization_on_outlined,
                        color: Colors.deepPurple,
                        isSelected: false, // Total is always summary
                        onTap: () => _onFilterTap(null), // Clear filter
                      ),
                    ],
                  ),
                ),

                // --- Filter Chips & Actions ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Row(
                    children: [
                      Text(
                        _dateRange != null
                            ? 'From ${DateFormat('MMM d').format(_dateRange!.start)} to ${DateFormat('MMM d').format(_dateRange!.end)}'
                            : 'All Invoices',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      if (_dateRange != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: InkWell(
                            onTap: () {
                              setState(() => _dateRange = null);
                              _loadInvoices();
                            },
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SalesInvoiceScreen(),
                            ),
                          ).then((_) => _loadInvoices()); // Refresh on return
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('New Sale'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                ),

                // --- Data Table ---
                Expanded(
                  child: InvoiceDataTable(
                    invoices: _filteredInvoices,
                    onView: _showInvoiceDetail, // Re-use existing modal logic
                    onPrint: (inv) async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Preparing to print...')),
                      );
                      try {
                        // Fetch full details
                        final details = await _apiService.getTransactionDetails(
                          inv['id'],
                        );

                        // Fetch Customer Balance if linked
                        double? currentBalance;
                        if (details['customer_id'] != null) {
                          try {
                            final cust = await _apiService.getCustomer(
                              details['customer_id'],
                            );
                            // 'current_debt' field holds current debt (>0)
                            currentBalance = double.tryParse(
                              cust['current_debt']?.toString() ?? '0',
                            );
                          } catch (e) {
                            debugPrint('Error fetching customer balance: $e');
                          }
                        }

                        if (!context.mounted) return;

                        await showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Select Print Format'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.receipt),
                                  title: const Text('Thermal Receipt'),
                                  subtitle: const Text('80mm Roll'),
                                  onTap: () async {
                                    Navigator.pop(ctx);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PdfPreviewScreen(
                                          transaction: details,
                                          useThermal: true,
                                          currentBalance: currentBalance,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.description),
                                  title: const Text('A4 Invoice'),
                                  subtitle: const Text('Professional Standard'),
                                  onTap: () async {
                                    Navigator.pop(ctx);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PdfPreviewScreen(
                                          transaction: details,
                                          useThermal: false,
                                          currentBalance: currentBalance,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error printing: $e')),
                        );
                      }
                    },
                    onShare: (inv) async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Generating Invoice PDF...'),
                        ),
                      );
                      try {
                        // Fetch full details
                        final details = await _apiService.getTransactionDetails(
                          inv['id'],
                        );

                        // Fetch Customer Balance if linked
                        double? currentBalance;
                        if (details['customer_id'] != null) {
                          try {
                            final cust = await _apiService.getCustomer(
                              details['customer_id'],
                            );
                            currentBalance = double.tryParse(
                              cust['balance']?.toString() ?? '0',
                            );
                          } catch (e) {
                            debugPrint('Error fetching customer balance: $e');
                          }
                        }

                        if (!context.mounted) return;
                        // Share
                        await ReceiptService.shareTransaction(
                          details,
                          currentBalance: currentBalance,
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error sharing: $e')),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
    );
  }

  void _showInvoiceDetail(Map<String, dynamic> invoice) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500, // Constrain width for desktop
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Invoice #${invoice['id']}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: [
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
                      trailing: Chip(
                        label: Text(invoice['status'] ?? 'N/A'),
                        backgroundColor:
                            (invoice['status'] == 'completed' ||
                                (double.tryParse(
                                          invoice['balance']?.toString() ?? '0',
                                        ) ??
                                        0) <=
                                    0)
                            ? Colors.green[100]
                            : Colors.orange[100],
                      ),
                    ),
                    const Divider(),
                    const Text(
                      'Items',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder(
                      future: _apiService.getTransactionDetails(invoice['id']),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const LinearProgressIndicator();
                        }
                        if (snapshot.hasError) {
                          return Text('Error loading items: ${snapshot.error}');
                        }

                        final details = snapshot.data as Map<String, dynamic>;
                        final items = details['items'] as List<dynamic>;

                        return Column(
                          children: items
                              .map(
                                (item) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(item['product_name']),
                                  subtitle: Text(
                                    '${item['quantity']} x ${item['unit_price']}',
                                  ),
                                  trailing: Text(
                                    'KES ${item['subtotal']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                    const Divider(thickness: 1.5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
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
                            onPressed: () async {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Preparing to print...'),
                                ),
                              );
                              try {
                                // Fetch full details
                                final details = await _apiService
                                    .getTransactionDetails(invoice['id']);

                                if (!mounted) return;

                                await showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Select Print Format'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ListTile(
                                          leading: const Icon(Icons.receipt),
                                          title: const Text('Thermal Receipt'),
                                          subtitle: const Text('80mm Roll'),
                                          onTap: () {
                                            Navigator.pop(ctx);
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    PdfPreviewScreen(
                                                      transaction: details,
                                                      useThermal: true,
                                                    ),
                                              ),
                                            );
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(
                                            Icons.description,
                                          ),
                                          title: const Text('A4 Invoice'),
                                          subtitle: const Text(
                                            'Professional Standard',
                                          ),
                                          onTap: () {
                                            Navigator.pop(ctx);
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    PdfPreviewScreen(
                                                      transaction: details,
                                                      useThermal: false,
                                                    ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error printing: $e')),
                                );
                              }
                            },
                            icon: const Icon(Icons.print),
                            label: const Text('Print'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Generating PDF...'),
                                ),
                              );
                              try {
                                // We already have 'invoice' map but it might be summary only.
                                // Ideally we need full details (items).
                                // Wait, _showInvoiceDetail receives 'invoice'.
                                // If it was opened from Table, it's the summary object.
                                // But the modal fetches items via FutureBuilder below.
                                // We should re-fetch details or use the result of FutureBuilder if possible.
                                // Easier to just re-fetch for sharing to ensure clean state.

                                final details = await _apiService
                                    .getTransactionDetails(invoice['id']);
                                if (!mounted) return;
                                await ReceiptService.shareTransaction(details);
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            },
                            icon: const Icon(Icons.share),
                            label: const Text('Share PDF'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // [NEW] Management Actions (Void / Edit)
                    if (invoice['status'] != 'voided')
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: FilledButton.icon(
                                onPressed: () => _editSale(invoice),
                                icon: const Icon(Icons.edit_note, size: 22),
                                label: const Text(
                                  'Edit Sale',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.blue[700],
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editSale(Map<String, dynamic> invoice) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Sale'),
        content: const Text(
          'This will load the sale into the POS for modification. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Edit in POS'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (mounted) Navigator.pop(context); // Close modal

      // 1. Fetch Details
      final details = await _apiService.getTransactionDetails(invoice['id']);

      // 2. [REMOVED] Do NOT Void Original (Backend handles reversal in updateSale)
      // await _apiService.voidSale(invoice['id']);

      if (!mounted) return;

      // 3. Populate POS
      final sales = Provider.of<SalesProvider>(context, listen: false);
      sales.addTab(); // Start fresh

      // [NEW] Set Editing ID
      sales.setEditingSale(invoice['id'].toString());

      final items = details['items'] as List<dynamic>;
      for (var item in items) {
        // Construct Product Model (Best Effort)
        final product = Product(
          id: item['product_id'],
          name: item['product_name'] ?? 'Unknown',
          sku: item['sku'] ?? 'N/A',
          type: item['type'] ?? 'retail',
          baseSellingPrice: double.tryParse(item['unit_price'].toString()) ?? 0,
          description: item['description'],
          category: item['category'] ?? 'General',
          // Defaults for required fields
          reorderLevel: 0,
          costPrice:
              double.tryParse(item['cost_price']?.toString() ?? '0') ?? 0,
          minWholesaleQty: 0,
          images: [],
          stockLevel: 0, // Not critical for POS line item
        );

        sales.addItem(
          product,
          quantity: double.tryParse(item['quantity'].toString()) ?? 1,
        );
      }

      // 4. Set Customer if linked
      if (details['customer_id'] != null) {
        sales.setCustomer({
          'id': details['customer_id'],
          'name': details['customer_name'],
          'email': details['email'],
          'phone': details['phone'],
        });
      }

      // 5. Restore Payment Amount (Fix for "0 Received" issue)
      final totalPaid =
          double.tryParse(details['total_paid']?.toString() ?? '0') ?? 0;
      if (totalPaid > 0) {
        sales.setAmountTendered(totalPaid);
      }

      // 5. Navigate
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SalesInvoiceScreen()),
      ).then((_) => _loadInvoices());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error preparing edit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
