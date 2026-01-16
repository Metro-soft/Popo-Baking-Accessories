import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import 'package:intl/intl.dart';

class PayActionsCard extends StatefulWidget {
  final int employeeId;
  final String employeeName;
  final double baseSalary;
  final String paymentPreference; // 'SPLIT' or 'FULL'
  final double? fixedAdvanceAmount;
  final VoidCallback onPaymentComplete;

  const PayActionsCard({
    super.key,
    required this.employeeId,
    required this.employeeName,
    required this.baseSalary,
    required this.paymentPreference,
    this.fixedAdvanceAmount,
    required this.onPaymentComplete,
  });

  @override
  State<PayActionsCard> createState() => _PayActionsCardState();
}

class _PayActionsCardState extends State<PayActionsCard> {
  final ApiService _api = ApiService();
  bool _isLoading = true;

  // Status for Current Month
  Map<String, dynamic>? _midMonthItem;
  Map<String, dynamic>? _endMonthItem;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void didUpdateWidget(covariant PayActionsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.employeeId != widget.employeeId) {
      _loadStatus();
    }
  }

  Future<void> _loadStatus() async {
    setState(() => _isLoading = true);
    try {
      final history = await _api.getEmployeeHistory(widget.employeeId);
      // Filter for THIS month (simplification: just look for recent draft/pending items or items from this month)
      // Actually, we should look for "Pending" items or "Paid" items for the current calendar month.
      // Better yet: Just look for any items labeled 'MID_MONTH' or 'END_MONTH' for the *current* month string?
      // Backend 'month' format is "January 2026".

      final currentMonthStr = DateFormat('MMMM yyyy').format(DateTime.now());

      // Reset
      _midMonthItem = null;
      _endMonthItem = null;

      for (var item in history) {
        if (item['month'] == currentMonthStr) {
          if (item['run_type'] == 'MID_MONTH') {
            _midMonthItem = item;
          } else {
            _endMonthItem = item;
          }
        }
      }
    } catch (e) {
      print('Error loading status: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePay(
    Map<String, dynamic>? item,
    double amount,
    String label,
    String runType,
  ) async {
    Map<String, dynamic>? payItem = item;

    if (payItem == null) {
      // Auto-create item on demand
      try {
        final currentMonthStr = DateFormat('MMMM yyyy').format(DateTime.now());
        payItem = await _api.ensurePayrollPayItem(
          employeeId: widget.employeeId,
          month: currentMonthStr,
          runType: runType,
        );
        // Refresh status in background to keep UI in sync
        _loadStatus();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to initialize payroll: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmPaymentDialog(
        employeeName: widget.employeeName,
        amount: amount,
        label: label,
      ),
    );

    if (confirmed == true) {
      try {
        await _api.finalizePayrollItem(payItem['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment recorded successfully!')),
          );
          _loadStatus();
          widget.onPaymentComplete();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final now = DateTime.now();
    final day = now.day;
    final isSplit = widget.paymentPreference == 'SPLIT';

    // Dynamic Calculations
    double advanceAmount = 0;
    if (isSplit) {
      if (widget.fixedAdvanceAmount != null && widget.fixedAdvanceAmount! > 0) {
        advanceAmount = widget.fixedAdvanceAmount!;
      } else {
        advanceAmount = widget.baseSalary * 0.40; // Default to 40%
      }
    }

    final double balanceAmount = isSplit
        ? (widget.baseSalary - advanceAmount)
        : widget.baseSalary;

    // 15th Logic
    final show15th = isSplit;
    final enable15th = day >= 15;
    final is15thPaid = _midMonthItem?['status'] == 'PAID';

    // 30th Logic
    final enable30th = day >= 25;
    final is30thPaid = _endMonthItem?['status'] == 'PAID';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.payments_outlined,
                size: 18,
                color: Colors.blue.shade800,
              ),
              const SizedBox(width: 8),
              Text(
                '${DateFormat('MMMM').format(now)} Payroll',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // 15th Button (Advance)
              if (show15th) ...[
                Expanded(
                  child: _buildPayButton(
                    label: 'Pay Advance (15th)',
                    amount: _midMonthItem != null
                        ? _midMonthItem!['net_pay']
                        : advanceAmount,
                    isPaid: is15thPaid,
                    isEnabled: enable15th,
                    onTap: () => _handlePay(
                      _midMonthItem,
                      advanceAmount,
                      'Advance Payment',
                      'MID_MONTH',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],

              // 30th Button (Balance/Full)
              Expanded(
                child: _buildPayButton(
                  label: isSplit ? 'Pay Balance (30th)' : 'Pay Salary (30th)',
                  amount: _endMonthItem != null
                      ? _endMonthItem!['net_pay']
                      : balanceAmount,
                  isPaid: is30thPaid,
                  isEnabled: enable30th,
                  onTap: () => _handlePay(
                    _endMonthItem,
                    balanceAmount,
                    'End-Month Salary',
                    'END_MONTH',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPayButton({
    required String label,
    dynamic amount,
    required bool isPaid,
    required bool isEnabled,
    required VoidCallback onTap,
    String? statusText,
  }) {
    Color bg = isPaid
        ? Colors.green.shade100
        : (isEnabled ? Colors.blue : Colors.grey.shade200);
    Color fg = isPaid
        ? Colors.green.shade800
        : (isEnabled ? Colors.white : Colors.grey);

    String text = label;
    if (isPaid) text = 'Paid';
    if (statusText != null) text = statusText;

    return InkWell(
      onTap: (isEnabled && !isPaid) ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              text,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            if (amount != null) ...[
              const SizedBox(height: 2),
              Text(
                'KES ${NumberFormat('#,##0').format(double.tryParse(amount.toString()) ?? 0)}',
                style: TextStyle(
                  color: fg.withValues(alpha: 0.8),
                  fontSize: 11,
                ),
              ),
            ],
            if (!isEnabled && !isPaid && statusText == null) ...[
              const SizedBox(height: 4),
              Icon(Icons.lock_clock, size: 14, color: fg),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConfirmPaymentDialog extends StatefulWidget {
  final String employeeName;
  final double amount;
  final String label;

  const _ConfirmPaymentDialog({
    required this.employeeName,
    required this.amount,
    required this.label,
  });

  @override
  State<_ConfirmPaymentDialog> createState() => _ConfirmPaymentDialogState();
}

class _ConfirmPaymentDialogState extends State<_ConfirmPaymentDialog> {
  // Can add bonus/deduction controllers here later if needed

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Confirm ${widget.label}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('You are about to pay ${widget.employeeName}:'),
          const SizedBox(height: 16),
          Text(
            'KES ${NumberFormat('#,##0.00').format(widget.amount)}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 16),
          const Text('This will record an expense and mark the item as paid.'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFA01B2D),
            foregroundColor: Colors.white,
          ),
          child: const Text('Confirm & Pay'),
        ),
      ],
    );
  }
}
