import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../../core/services/api_service.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  bool _isLoading = false;

  // Form Fields
  String _name = '';
  String _sku = '';
  String _type = 'retail'; // Default
  double _sellingPrice = 0.0;
  double? _rentalDeposit;
  int _reorderLevel = 10;

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      final newProduct = Product(
        name: _name,
        sku: _sku,
        type: _type,
        // description: _description, // Removed unused field
        baseSellingPrice: _sellingPrice,
        rentalDeposit: _type == 'asset_rental' ? _rentalDeposit : null,
        reorderLevel: _reorderLevel,
      );

      await _apiService.createProduct(newProduct);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product Created Successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _formKey.currentState!.reset();
        setState(() {
          _type = 'retail'; // Reset type
          _rentalDeposit = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Product')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive: Desktop centered card, Mobile full width
          if (constraints.maxWidth > 600) {
            return Center(
              child: SizedBox(
                width: 600,
                child: Card(
                  elevation: 4,
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: _buildForm(),
                  ),
                ),
              ),
            );
          } else {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildForm(),
            );
          }
        },
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Name
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Product Name',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              onSaved: (v) => _name = v ?? '',
            ),
            const SizedBox(height: 16),

            // SKU
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'SKU (Barcode)',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              onSaved: (v) => _sku = v ?? '',
            ),
            const SizedBox(height: 16),

            // Type Dropdown (The Toggle)
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Product Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'retail',
                  child: Text('Retail Item (Sale)'),
                ),
                DropdownMenuItem(
                  value: 'asset_rental',
                  child: Text('Rental Asset (Hire)'),
                ),
                DropdownMenuItem(
                  value: 'raw_material',
                  child: Text('Raw Material (Internal Use)'),
                ),
              ],
              onChanged: (val) {
                setState(() {
                  _type = val ?? 'retail';
                });
              },
              onSaved: (v) => _type = v ?? 'retail',
            ),
            const SizedBox(height: 16),

            // Selling Price
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Base Selling Price',
                prefixText: 'KES ',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) => v == null || double.tryParse(v) == null
                  ? 'Invalid Price'
                  : null,
              onSaved: (v) => _sellingPrice = double.tryParse(v ?? '0') ?? 0.0,
            ),
            const SizedBox(height: 16),

            // Conditional Rental Deposit
            if (_type == 'asset_rental') ...[
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Rental Deposit Amount',
                  prefixText: 'KES ',
                  border: OutlineInputBorder(),
                  helperText: 'Refundable security deposit for this asset',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  if (_type == 'asset_rental' &&
                      (v == null || double.tryParse(v) == null)) {
                    return 'Required for Rentals';
                  }
                  return null;
                },
                onSaved: (v) => _rentalDeposit = double.tryParse(v ?? '0'),
              ),
              const SizedBox(height: 16),
            ],

            // Reorder Level
            TextFormField(
              initialValue: '10',
              decoration: const InputDecoration(
                labelText: 'Low Stock Alert Level',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onSaved: (v) => _reorderLevel = int.tryParse(v ?? '10') ?? 10,
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'SAVE PRODUCT',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
