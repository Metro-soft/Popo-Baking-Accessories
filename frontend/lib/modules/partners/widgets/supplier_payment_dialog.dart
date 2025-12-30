import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_service.dart';

class SupplierPaymentDialog extends StatefulWidget {
  final Map<String, dynamic> supplier;
  final VoidCallback onSuccess;

  const SupplierPaymentDialog({
    super.key,
    required this.supplier,
    required this.onSuccess,
  });

  @override
  State<SupplierPaymentDialog> createState() => _SupplierPaymentDialogState();
}

class _SupplierPaymentDialogState extends State<SupplierPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedMethod = 'cash';
  bool _isSubmitting = false;

  final List<Map<String, String>> _paymentMethods = [
    {'value': 'cash', 'label': 'Cash'},
    {'value': 'mpesa', 'label': 'M-Pesa'},
    {'value': 'bank_transfer', 'label': 'Bank Transfer'},
    {'value': 'cheque', 'label': 'Cheque'},
  ];

  @override
  void initState() {
    super.initState();
    // Pre-fill with debt amount if it exists (positive balance means we owe)
    final debt =
        double.tryParse(
          widget.supplier['current_balance']?.toString() ?? '0',
        ) ??
        0;
    if (debt > 0) {
      _amountController.text = debt.toStringAsFixed(0);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final amount = double.parse(_amountController.text);
      final data = {
        'amount': amount,
        'method': _selectedMethod,
        'reference': _referenceController.text.trim(),
        'notes': _notesController.text.trim(),
      };

      await ApiService().addSupplierPayment(widget.supplier['id'], data);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment recorded successfully')),
        );
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat("#,##0.00", "en_US");
    final debt =
        double.tryParse(
          widget.supplier['current_balance']?.toString() ?? '0',
        ) ??
        0;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.payments_outlined, color: Colors.blue),
          SizedBox(width: 8),
          Text('Record Payment Out'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment to: ${widget.supplier['name']}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Outstandng Balance: KES ${currencyFormat.format(debt)}',
                      style: TextStyle(color: Colors.blue[700]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount (KES)',
                  border: OutlineInputBorder(),
                  prefixText: 'KES ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  final v = double.tryParse(value);
                  if (v == null || v <= 0) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _selectedMethod,
                decoration: const InputDecoration(
                  labelText: 'Payment Method',
                  border: OutlineInputBorder(),
                ),
                items: _paymentMethods.map((m) {
                  return DropdownMenuItem(
                    value: m['value'],
                    child: Text(m['label']!),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedMethod = val!),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: 'Reference Code (Optional)',
                  hintText: 'e.g. M-Pesa Code, Cheque No',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: Colors.blue),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save Payment'),
        ),
      ],
    );
  }
}
