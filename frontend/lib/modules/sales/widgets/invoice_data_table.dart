import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class InvoiceDataTable extends StatelessWidget {
  final List<dynamic> invoices;
  final Function(Map<String, dynamic>) onView;
  final Function(Map<String, dynamic>) onPrint;
  final Function(Map<String, dynamic>) onShare;

  const InvoiceDataTable({
    super.key,
    required this.invoices,
    required this.onView,
    required this.onPrint,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) {
      return Center(
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
              'No invoices found',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Container(
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
      margin: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth,
                ), // Ensure table fills width or scrolls
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
                  horizontalMargin: 24,
                  columnSpacing: 32,
                  columns: const [
                    DataColumn(
                      label: Text(
                        'DATE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'INVOICE #',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'CUSTOMER',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'AMOUNT',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'STATUS',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'ACTIONS',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  rows: invoices.map((inv) {
                    final balance =
                        double.tryParse(inv['balance'].toString()) ?? 0;
                    final isPaid = balance <= 0;
                    final date = DateTime.parse(inv['created_at']);

                    return DataRow(
                      onSelectChanged: (_) => onView(inv),
                      cells: [
                        // Date
                        DataCell(
                          Text(
                            DateFormat('MMM d, yyyy').format(date),
                            style: TextStyle(color: Colors.grey[800]),
                          ),
                        ),
                        // Invoice #
                        DataCell(
                          Text(
                            '#${inv['id']}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        // Customer
                        DataCell(
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.deepPurple[50],
                                child: Text(
                                  (inv['customer_name'] ?? 'W')[0]
                                      .toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.deepPurple[400],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(inv['customer_name'] ?? 'Walk-in'),
                            ],
                          ),
                        ),
                        // Amount
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'KES ${inv['total_amount']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (!isPaid)
                                Text(
                                  'Bal: ${inv['balance']}',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Status Badge
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isPaid
                                  ? Colors.green[50]
                                  : Colors.orange[50],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isPaid
                                    ? Colors.green[100]!
                                    : Colors.orange[100]!,
                              ),
                            ),
                            child: Text(
                              isPaid
                                  ? 'PAID'
                                  : 'UNPAID', // Simplified status for now
                              style: TextStyle(
                                color: isPaid
                                    ? Colors.green[700]
                                    : Colors.orange[800],
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        // Actions
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.print_outlined,
                                  size: 20,
                                ),
                                tooltip: 'Print Receipt',
                                color: Colors.grey[600],
                                onPressed: () => onPrint(inv),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.share_outlined,
                                  size: 20,
                                ),
                                tooltip: 'Share WhatsApp',
                                color: Colors.grey[600],
                                onPressed: () => onShare(inv),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
