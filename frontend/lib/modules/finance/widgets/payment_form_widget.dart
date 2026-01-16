import 'package:flutter/material.dart';

class PaymentFormWidget extends StatefulWidget {
  final Map<String, dynamic> item;
  final String employeeName;
  final Function(double bonus, double deductions) onSave;
  final VoidCallback onCancel;

  const PaymentFormWidget({
    super.key,
    required this.item,
    required this.employeeName,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<PaymentFormWidget> createState() => _PaymentFormWidgetState();
}

class _PaymentFormWidgetState extends State<PaymentFormWidget> {
  late TextEditingController _bonusCtrl;
  late TextEditingController _deductCtrl;

  @override
  void initState() {
    super.initState();
    _bonusCtrl = TextEditingController(text: widget.item['bonuses'].toString());
    _deductCtrl = TextEditingController(
      text: widget.item['deductions'].toString(),
    );
  }

  @override
  void dispose() {
    _bonusCtrl.dispose();
    _deductCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Edit Pay: ${widget.item['employee_name'] ?? widget.employeeName}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Base Salary: KES ${widget.item['base_salary']}',
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _bonusCtrl,
            decoration: const InputDecoration(
              labelText: 'Bonuses',
              prefixText: 'KES ',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _deductCtrl,
            decoration: const InputDecoration(
              labelText: 'Deductions',
              prefixText: 'KES ',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  final bonus = double.tryParse(_bonusCtrl.text) ?? 0;
                  final deduct = double.tryParse(_deductCtrl.text) ?? 0;
                  widget.onSave(bonus, deduct);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA01B2D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
