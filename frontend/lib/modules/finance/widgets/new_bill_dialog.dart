import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_service.dart';

class NewBillDialog extends StatefulWidget {
  const NewBillDialog({super.key});

  @override
  State<NewBillDialog> createState() => _NewBillDialogState();
}

class _NewBillDialogState extends State<NewBillDialog> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _api = ApiService();

  bool _isLoading = true;
  bool _isSaving = false;
  List<dynamic> _categories = [];

  // Form Fields
  int? _selectedCategory;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _vendorCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _dueDayCtrl = TextEditingController();

  // Payment Details
  String _paymentType = 'Paybill';
  String _frequency = 'monthly';
  String _vendorLabel = 'Vendor (e.g. Landlord)';
  String? _duePreview;

  // Specific Method Controllers
  final _paybillBusinessCtrl = TextEditingController();
  final _paybillAccountCtrl = TextEditingController();
  final _tillNumberCtrl = TextEditingController();
  final _phoneNumberCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _bankAccountCtrl = TextEditingController();
  final _bankAccountNameCtrl = TextEditingController();
  final _otherDetailsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _api.getExpenseCategories();
      if (mounted) {
        setState(() {
          _categories = cats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Fail silently or show error in UI?
      }
    }
  }

  void _updateVendorLabel(int? catId) {
    if (catId == null) return;

    final cat = _categories.firstWhere(
      (c) => c['id'] == catId,
      orElse: () => null,
    );
    if (cat == null) return;

    String name = cat['name'];

    // Auto-fill Name if likely
    bool isLikelyAutoFilled =
        _nameCtrl.text.isEmpty ||
        _categories.any((c) => c['name'] == _nameCtrl.text);
    if (isLikelyAutoFilled) {
      _nameCtrl.text = name;
    }

    // Smart Vendor Label
    setState(() {
      if (name.toLowerCase().contains('rent')) {
        _vendorLabel = 'Landlord Name';
      } else if (name.toLowerCase().contains('salary') ||
          name.toLowerCase().contains('wages')) {
        _vendorLabel = 'Employee / Department';
      } else if (name.toLowerCase().contains('util')) {
        _vendorLabel = 'Service Provider (e.g. KPLC)';
      } else if (name.toLowerCase().contains('internet') ||
          name.toLowerCase().contains('data')) {
        _vendorLabel = 'ISP (e.g. Safaricom/Zuku)';
      } else if (name.toLowerCase().contains('fee')) {
        _vendorLabel = 'Platform (e.g. Bank)';
      } else {
        _vendorLabel = 'Vendor / Payee';
      }
    });
  }

  void _updateDuePreview(String val) {
    final day = int.tryParse(val);
    if (day != null && day >= 1 && day <= 31) {
      final now = DateTime.now();
      DateTime candidate = DateTime(now.year, now.month, day);
      // If day already passed this month, move to next month
      if (candidate.isBefore(DateTime(now.year, now.month, now.day))) {
        candidate = DateTime(now.year, now.month + 1, day);
      }
      setState(() {
        _duePreview =
            'Next occurrence: ${DateFormat('EEE, MMM d, y').format(candidate)}';
      });
    } else {
      setState(() => _duePreview = null);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    // Construct instructions string
    String instructions = '';
    if (_paymentType == 'Paybill') {
      instructions =
          'Paybill: ${_paybillBusinessCtrl.text}, Acc: ${_paybillAccountCtrl.text}';
    } else if (_paymentType == 'Buy Goods') {
      instructions = 'Till: ${_tillNumberCtrl.text}';
    } else if (_paymentType == 'Send Money') {
      instructions = 'Send Money: ${_phoneNumberCtrl.text}';
    } else if (_paymentType == 'Bank Transfer') {
      instructions =
          'Bank: ${_bankNameCtrl.text}, Acc: ${_bankAccountCtrl.text}, Name: ${_bankAccountNameCtrl.text}';
    } else {
      instructions = _otherDetailsCtrl.text;
    }

    try {
      await _api.createBill({
        'name': _nameCtrl.text,
        'vendor': _vendorCtrl.text,
        'amount': double.parse(_amountCtrl.text),
        'due_day': int.parse(_dueDayCtrl.text),
        'category_id': _selectedCategory,
        'auto_pay': false, // Disabled feature
        'frequency': _frequency,
        'payment_instructions': instructions,
      });

      if (!mounted) return;
      Navigator.pop(context, true); // Return true on success
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Recurring Bill'),
      content: _isLoading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: _categories.map<DropdownMenuItem<int>>((c) {
                        return DropdownMenuItem(
                          value: c['id'],
                          child: Text(c['name']),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedCategory = val);
                        _updateVendorLabel(val);
                      },
                      validator: (val) => val == null ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Bill Name (e.g. Rent)',
                      ),
                      validator: (val) => val!.isEmpty ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: _vendorCtrl,
                      decoration: InputDecoration(labelText: _vendorLabel),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Payment Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _paymentType,
                      decoration: const InputDecoration(labelText: 'Method'),
                      items:
                          [
                                'Paybill',
                                'Buy Goods',
                                'Send Money',
                                'Bank Transfer',
                                'Other',
                              ]
                              .map(
                                (m) =>
                                    DropdownMenuItem(value: m, child: Text(m)),
                              )
                              .toList(),
                      onChanged: (val) => setState(() => _paymentType = val!),
                    ),
                    if (_paymentType == 'Paybill') ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _paybillBusinessCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Business No.',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _paybillAccountCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Account No.',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else if (_paymentType == 'Buy Goods') ...[
                      TextFormField(
                        controller: _tillNumberCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Till Number',
                        ),
                      ),
                    ] else if (_paymentType == 'Send Money') ...[
                      TextFormField(
                        controller: _phoneNumberCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number (e.g. 07...)',
                        ),
                      ),
                    ] else if (_paymentType == 'Bank Transfer') ...[
                      TextFormField(
                        controller: _bankNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Bank Name',
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _bankAccountCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Account No.',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _bankAccountNameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Account Name',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      TextFormField(
                        controller: _otherDetailsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Instructions',
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Amount (KES)',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (val) => val!.isEmpty ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: _dueDayCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Due Day (1-31)',
                        hintText: 'e.g. 5',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: _updateDuePreview,
                      validator: (val) {
                        if (val!.isEmpty) return 'Required';
                        final n = int.tryParse(val);
                        if (n == null || n < 1 || n > 31) return 'Invalid day';
                        return null;
                      },
                    ),
                    if (_duePreview != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 12),
                        child: Text(
                          _duePreview!,
                          style: TextStyle(
                            color: Colors.blueGrey[600],
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _frequency,
                      decoration: const InputDecoration(labelText: 'Frequency'),
                      items: ['monthly', 'weekly', 'quarterly', 'yearly']
                          .map(
                            (f) => DropdownMenuItem(
                              value: f,
                              child: Text(toBeginningOfSentenceCase(f)!),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => _frequency = val!),
                    ),
                  ],
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create Bill'),
        ),
      ],
    );
  }
}
