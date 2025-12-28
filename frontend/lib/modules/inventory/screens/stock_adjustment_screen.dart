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
  double _quantity = 0;
  String _action = 'Remove'; // Default to Remove (Loss/Damage is most common)
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
      // Calculate final change based on Action
      double finalChange = _quantity;
      if (_action == 'Remove') {
        finalChange = -_quantity;
      }

      await _apiService.adjustStock(
        _selectedProduct!.id ?? 0,
        finalChange,
        _reason,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock Adjusted Successfully')),
        );
        _formKey.currentState!.reset();
        setState(() {
          _selectedProduct = null;
          _quantity = 0;
          _action = 'Remove'; // Reset to default
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
                key: ValueKey(
                  _selectedProduct,
                ), // Use Key to force rebuild on reset
                initialValue: _selectedProduct,
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

              // Action Selector (Add/Remove)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Action',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.swap_vert),
                ),
                initialValue: _action,
                items: ['Add', 'Remove']
                    .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                    .toList(),
                onChanged: (val) => setState(() => _action = val!),
              ),
              const SizedBox(height: 24),

              // Reason Selector
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.info_outline),
                ),
                initialValue: _reason,
                items: _reasons
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (val) => setState(() => _reason = val!),
              ),
              const SizedBox(height: 24),

              // Quantity Input
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  helperText: 'Enter positive amount',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers),
                ),
                keyboardType: const TextInputType.numberWithOptions(),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter quantity';
                  final v = double.tryParse(val);
                  if (v == null || v <= 0) return 'Must be greater than zero';
                  return null;
                },
                onSaved: (val) => _quantity = double.parse(val!),
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
