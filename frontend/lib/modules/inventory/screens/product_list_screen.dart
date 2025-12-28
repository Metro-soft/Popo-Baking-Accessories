import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../models/product_model.dart';
import 'add_product_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final ApiService _apiService = ApiService();
  List<Product> _products = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final products = await _apiService.getProducts();
      setState(() => _products = products);
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
      appBar: AppBar(
        title: const Text('Popo Baking Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadProducts),
        ],
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Quick Stats or Header
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('Active Inventory: ${_products.length} Items'),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _products.length,
                    itemBuilder: (ctx, i) {
                      final p = _products[i];
                      return ListTile(
                        leading: _buildTypeDot(p.type),
                        title: Text(p.name),
                        subtitle: Text(
                          'SKU: ${p.sku} | Price: ${p.baseSellingPrice}',
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddProductScreen()),
          ).then((_) => _loadProducts());
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTypeDot(String type) {
    Color color = Colors.blue;
    if (type == 'retail') color = Colors.green;
    if (type == 'asset_rental') color = Colors.orange;
    if (type == 'service_print') color = Colors.purple;
    if (type == 'raw_material') color = Colors.brown;

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
