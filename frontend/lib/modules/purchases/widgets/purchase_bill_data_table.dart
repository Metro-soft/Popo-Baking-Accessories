import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PurchaseBillDataTable extends StatelessWidget {
  final List<dynamic> bills;
  final Function(Map<String, dynamic>) onPay;

  const PurchaseBillDataTable({
    super.key,
    required this.bills,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    if (bills.isEmpty) {
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
              'No bills found',
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
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
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
                        'BILL #',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'SUPPLIER',
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
                  rows: bills.map((bill) {
                    final balance =
                        (double.tryParse(bill['total_amount'].toString()) ??
                            0) -
                        (double.tryParse(bill['total_paid'].toString()) ?? 0);
                    final isPaid = balance <= 0.01;
                    final date =
                        DateTime.tryParse(
                          bill['created_at']?.toString() ?? '',
                        ) ??
                        DateTime.now();
                    final status = bill['payment_status'] ?? 'unpaid';

                    return DataRow(
                      cells: [
                        // Date
                        DataCell(
                          Text(
                            DateFormat('MMM d, yyyy').format(date),
                            style: TextStyle(color: Colors.grey[800]),
                          ),
                        ),
                        // Bill #
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '#${bill['id']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (bill['reference_no'] != null)
                                Text(
                                  bill['reference_no'],
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Supplier
                        DataCell(
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor:
                                    Colors.blue[50], // Blue for Suppliers
                                child: Text(
                                  (bill['supplier_name'] ?? 'S')[0]
                                      .toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue[800],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(bill['supplier_name'] ?? 'Unknown'),
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
                                'KES ${bill['total_amount']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (!isPaid)
                                Text(
                                  'Bal: ${balance.toStringAsFixed(2)}',
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
                              color: _getStatusColor(
                                status,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _getStatusColor(
                                  status,
                                ).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                color: _getStatusColor(status),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        // Actions
                        DataCell(
                          (!isPaid)
                              ? IconButton(
                                  icon: const Icon(Icons.payment, size: 20),
                                  tooltip: 'Record Payment',
                                  color: Colors.green[700],
                                  onPressed: () => onPay(bill),
                                )
                              : const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 20,
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

  Color _getStatusColor(String status) {
    if (status == 'paid') return Colors.green;
    if (status == 'partial') return Colors.orange;
    return Colors.red;
  }
}
