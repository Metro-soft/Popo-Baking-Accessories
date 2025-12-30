import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_service.dart';
import '../../core/services/statement_pdf_service.dart';

class TransactionDetailsDialog extends StatefulWidget {
  final int transactionId;
  final String type; // 'order' (Customer) or 'bill' (Supplier)
  final String title;

  const TransactionDetailsDialog({
    super.key,
    required this.transactionId,
    required this.type,
    this.title = 'Transaction Details',
  });

  @override
  State<TransactionDetailsDialog> createState() =>
      _TransactionDetailsDialogState();
}

class _TransactionDetailsDialogState extends State<TransactionDetailsDialog> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _data;
  final NumberFormat _currencyFormat = NumberFormat("#,##0.00", "en_US");

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      Map<String, dynamic> data;
      if (widget.type == 'bill') {
        data = await _apiService.getPurchaseOrderDetails(widget.transactionId);
      } else {
        data = await _apiService.getOrderDetails(widget.transactionId);
      }

      if (mounted) {
        setState(() {
          _data = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading details: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading details...'),
          ],
        ),
      );
    }

    if (_data == null) return const SizedBox.shrink();

    final isBill = widget.type == 'bill';
    final items = (_data!['items'] as List<dynamic>?) ?? [];
    final date = DateTime.parse(_data!['created_at']);
    final total =
        double.tryParse(
          _data![isBill ? 'total_product_cost' : 'total_amount'].toString(),
        ) ??
        0;
    final status = _data!['status']?.toString().toUpperCase() ?? 'UNKNOWN';

    // Supplier or Customer Name
    final partyName = isBill
        ? _data!['supplier_name']
        : _data!['customer_name'];
    final partyLabel = isBill ? 'Supplier' : 'Customer';

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isBill ? Icons.inventory_2_outlined : Icons.receipt_long,
            color: isBill ? Colors.blue : Colors.green,
          ),
          const SizedBox(width: 8),
          Text(widget.title),
        ],
      ),
      content: SizedBox(
        width: 600, // Wider for tables
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${widget.transactionId}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM dd, yyyy h:mm a').format(date),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: status == 'COMPLETED' || status == 'RECEIVED'
                          ? Colors.green[100]
                          : Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: status == 'COMPLETED' || status == 'RECEIVED'
                            ? Colors.green[800]
                            : Colors.orange[900],
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Party Details
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          partyLabel,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          partyName ?? 'Unknown',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (_data!['phone'] != null)
                          Text(
                            _data!['phone'],
                            style: const TextStyle(fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                  if (isBill) ...[
                    // Extra PO Costs
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Transport: KES ${_currencyFormat.format(double.tryParse(_data!['transport_cost']?.toString() ?? '0') ?? 0)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            'Packaging: KES ${_currencyFormat.format(double.tryParse(_data!['packaging_cost']?.toString() ?? '0') ?? 0)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),

              // Items Table
              const Text(
                'Line Items',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(3), // Product
                    1: FlexColumnWidth(1), // Qty
                    2: FlexColumnWidth(1.5), // Price
                    3: FlexColumnWidth(1.5), // Total
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    // Header
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey[50]),
                      children: [
                        _buildHeaderCell('Product'),
                        _buildHeaderCell('Qty', align: TextAlign.center),
                        _buildHeaderCell(
                          isBill ? 'Cost' : 'Price',
                          align: TextAlign.right,
                        ),
                        _buildHeaderCell('Total', align: TextAlign.right),
                      ],
                    ),
                    // Rows
                    ...items.map((item) {
                      final name = item['product_name'] ?? 'Unknown Item';
                      final qty =
                          double.tryParse(
                            item[isBill ? 'quantity_received' : 'quantity']
                                .toString(),
                          ) ??
                          0;
                      final price =
                          double.tryParse(
                            item[isBill ? 'supplier_unit_price' : 'unit_price']
                                .toString(),
                          ) ??
                          0;
                      final subtotal = qty * price;

                      return TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (item['sku'] != null)
                                  Text(
                                    item['sku'],
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              qty.toString(),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              _currencyFormat.format(price),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              _currencyFormat.format(subtotal),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Totals
              Align(
                alignment: Alignment.centerRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total Amount',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    Text(
                      'KES ${_currencyFormat.format(total)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isBill ? Colors.blue[800] : Colors.green[800],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: () async {
            if (_data != null) {
              await StatementPdfService.printTransaction(
                data: _data!,
                type: widget.type == 'bill' ? 'Bill' : 'Invoice',
              );
            }
          },
          icon: const Icon(Icons.print, size: 18),
          label: const Text('Print'),
        ),
      ],
    );
  }

  Widget _buildHeaderCell(String text, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      child: Text(
        text.toUpperCase(),
        textAlign: align,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: Colors.black54,
        ),
      ),
    );
  }
}
