import 'package:flutter/material.dart';

class PaymentModal extends StatefulWidget {
  final double totalAmount;
  final Map<String, dynamic>? customer;
  final Function(List<Map<String, dynamic>>) onConfirm;

  const PaymentModal({
    super.key,
    required this.totalAmount,
    this.customer,
    required this.onConfirm,
  });

  @override
  State<PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<PaymentModal> {
  String _method = 'cash';
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _refCtrl = TextEditingController();

  double get _enteredAmount => double.tryParse(_amountCtrl.text) ?? 0.0;

  // Credit Logic
  bool get _isCredit => _method == 'credit';
  bool get _canOfferCredit {
    if (widget.customer == null) return false;
    final debt =
        double.tryParse(widget.customer!['current_debt'].toString()) ?? 0.0;
    final limit =
        double.tryParse(widget.customer!['credit_limit'].toString()) ?? 5000.0;
    return (debt + widget.totalAmount) <= limit;
  }

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = widget.totalAmount.toStringAsFixed(2);
  }

  void _submit() {
    // If Full Credit, we send NO payments.
    if (_method == 'credit') {
      if (!_canOfferCredit) {
        // Should be blocked by UI, but double check
        return;
      }
      widget.onConfirm([]); // Empty/No payments = Full Debt
      Navigator.pop(context);
      return;
    }

    final amt = _enteredAmount;
    if (amt <= 0) return;

    widget.onConfirm([
      {'method': _method, 'amount': amt, 'referenceCode': _refCtrl.text},
    ]);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Total: KES ${widget.totalAmount.toStringAsFixed(2)}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.customer != null &&
                !_canOfferCredit &&
                _method == 'credit')
              Container(
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(8),
                color: Colors.red[50],
                child: Row(
                  children: const [
                    Icon(Icons.block, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Credit Limit Reached. Collect Cash.',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            DropdownButtonFormField<String>(
              initialValue: _method,
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'mpesa', child: Text('M-Pesa')),
                DropdownMenuItem(
                  value: 'credit',
                  child: Text('On Account (Full Credit)'),
                ),
              ],
              onChanged: (v) {
                setState(() => _method = v!);
                if (_method == 'credit' && widget.customer == null) {
                  // Force back to cash if no customer
                  Future.delayed(Duration.zero, () {
                    setState(() => _method = 'cash');
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please select a customer first to use Credit',
                      ),
                    ),
                  );
                }
              },
              decoration: const InputDecoration(
                labelText: 'Payment Method',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),

            // Amount Field - Hidden if Full Credit
            if (_method != 'credit')
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount Paid (KES)',
                  border: OutlineInputBorder(),
                  helperText: 'Enter amount received. Balance acts as debt.',
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.blue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Full amount (KES ${widget.totalAmount.toStringAsFixed(2)}) will be added to ${widget.customer?['name'] ?? 'Customer'}\'s debt.',
                        style: TextStyle(color: Colors.blue[900]),
                      ),
                    ),
                  ],
                ),
              ),

            if (_method == 'mpesa')
              Padding(
                padding: const EdgeInsets.only(top: 15),
                child: TextField(
                  controller: _refCtrl,
                  decoration: const InputDecoration(
                    labelText: 'M-Pesa Code',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: (_method == 'credit' && !_canOfferCredit) ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isCredit && !_canOfferCredit
                ? Colors.grey
                : Colors.green,
            foregroundColor: Colors.white,
          ),
          child: const Text('CONFIRM PAYMENT'),
        ),
      ],
    );
  }
}
