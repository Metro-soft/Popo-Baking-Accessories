import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../models/product_model.dart';

class StockAdjustmentScreen extends StatefulWidget {
  const StockAdjustmentScreen({super.key});

  @override
  State<StockAdjustmentScreen> createState() => _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends State<StockAdjustmentScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  Product? _selectedProduct;
  List<Product> _products = [];
  bool _isLoading = false;

  // Form Fields
  double _quantityChange = 0;
  String _reason = 'Damaged';
  final List<String> _reasons = [
    'Damaged',
    'Expired',
    'Theft',
    'Count Correction',
    'Found Stock',
  ];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _apiService.getProducts();
      setState(() {
        _products = products;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _submitAdjustment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProduct == null) return;

    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      // Determine sign based on reason or manual input?
      // Let's assume user enters positive for add, negative for remove?
      // Or better: Use "Action" dropdown (Add/Remove)

      await _apiService.adjustStock(
        _selectedProduct!.id ?? 0,
        _quantityChange,
        _reason,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock Adjusted Successfully')),
        );
        _formKey.currentState!.reset();
        setState(() {
          _selectedProduct = null;
          _quantityChange = 0;
        });
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stock Adjustment')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Adjust Inventory Levels',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Use this to write off damaged items or correct stock counts.',
              ),
              const SizedBox(height: 32),

              // Product Selector
              DropdownButtonFormField<Product>(
                decoration: const InputDecoration(
                  labelText: 'Select Product',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory_2),
                ),
                // value: _selectedProduct, // Deprecated, using FormField state
                items: _products.map((p) {
                  return DropdownMenuItem(
                    value: p,
                    child: Text('${p.name} (SKU: ${p.sku})'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedProduct = val),
                validator: (val) =>
                    val == null ? 'Please select a product' : null,
              ),
              const SizedBox(height: 24),

              // Reason Selector
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.info_outline),
                ),
                initialValue: _reason, // Set initial value here
                items: _reasons
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (val) => setState(() => _reason = val!),
              ),
              const SizedBox(height: 24),

              // Quantity Input
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Quantity Change (+/-)',
                  helperText: 'Enter negative value to reduce stock (e.g. -5)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter quantity';
                  if (double.tryParse(val) == 0) return 'Cannot be zero';
                  return null;
                },
                onSaved: (val) => _quantityChange = double.parse(val!),
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitAdjustment,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Confirm Adjustment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange, // Warning color
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
