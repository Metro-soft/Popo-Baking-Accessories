import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/responsive_layout.dart';
import 'add_product_screen.dart';

class ProductProvider with ChangeNotifier {
  List<Product> _products = [];
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  List<Product> get products => _products;
  bool get isLoading => _isLoading;

  Future<void> fetchProducts() async {
    _isLoading = true;
    notifyListeners();
    try {
      _products = await _apiService.getProducts();
    } catch (e) {
      // print(e); // Removed print for lint
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addProduct(Product product) async {
    try {
      final newProduct = await _apiService.createProduct(product);
      _products.add(newProduct);
      notifyListeners();
    } catch (e) {
      // print(e); // Removed print for lint
    }
  }
}

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  State<ProductManagementScreen> createState() =>
      _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductProvider>(context, listen: false).fetchProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory),
            tooltip: 'Stock Entry',
            onPressed: () => Navigator.pushNamed(context, '/stock-entry'),
          ),
        ],
      ),
      body: Consumer<ProductProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.products.isEmpty) {
            return const Center(child: Text('No products found.'));
          }

          return ResponsiveLayout(
            mobileBody: _buildMobileList(provider.products),
            desktopBody: _buildDesktopTable(provider.products),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Placeholder for add product dialog
          _showAddProductDialog(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMobileList(List<Product> products) {
    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return ListTile(
          title: Text(product.name),
          subtitle: Text(
            'SKU: ${product.sku} | Price: ${product.baseSellingPrice}',
          ),
          trailing: Chip(
            label: Text(product.type),
            backgroundColor: product.type == 'retail'
                ? Colors.blue[100]
                : Colors.amber[100],
          ),
        );
      },
    );
  }

  Widget _buildDesktopTable(List<Product> products) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('SKU')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Price')),
            DataColumn(label: Text('Min Stock')),
          ],
          rows: products.map((product) {
            return DataRow(
              cells: [
                DataCell(Text(product.name)),
                DataCell(Text(product.sku)),
                DataCell(
                  Chip(
                    label: Text(product.type),
                    backgroundColor: product.type == 'retail'
                        ? Colors.blue[100]
                        : Colors.amber[100],
                  ),
                ),
                DataCell(Text(product.baseSellingPrice.toStringAsFixed(2))),
                DataCell(Text(product.reorderLevel.toString())),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showAddProductDialog(BuildContext context) {
    // Navigate to the new Smart Form Screen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddProductScreen()),
    ).then((_) {
      // Refresh list on return
      if (context.mounted) {
        Provider.of<ProductProvider>(context, listen: false).fetchProducts();
      }
    });
  }
}
