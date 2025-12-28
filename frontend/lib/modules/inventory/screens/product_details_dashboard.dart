import 'package:flutter/material.dart';
import '../models/product_model.dart';
import 'bulk_variant_screen.dart';
import 'add_product_screen.dart';
import '../../core/services/printing_service.dart';
import '../../core/services/api_service.dart';

class ProductDetailsDashboard extends StatefulWidget {
  final Product product;
  final Function(Product)? onEdit;
  const ProductDetailsDashboard({
    super.key,
    required this.product,
    this.onEdit,
  });

  @override
  State<ProductDetailsDashboard> createState() =>
      _ProductDetailsDashboardState();
}

class _ProductDetailsDashboardState extends State<ProductDetailsDashboard> {
  late Product _currentProduct;

  @override
  void initState() {
    super.initState();
    _currentProduct = widget.product;
  }

  Future<void> _refreshProduct() async {
    try {
      final updated = await ApiService().getProductById(_currentProduct.id!);
      if (mounted) {
        setState(() => _currentProduct = updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to refresh: $e')));
      }
    }
  }

  Future<void> _editProduct() async {
    if (widget.onEdit != null) {
      widget.onEdit!(_currentProduct);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(product: _currentProduct),
      ),
    );
    // Refresh regardless of result in case they saved
    if (mounted) await _refreshProduct();
  }

  Future<void> _deleteProduct() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text(
          'Are you sure you want to delete "${_currentProduct.name}"?\n\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ApiService().deleteProduct(_currentProduct.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product deleted successfully')),
          );
          Navigator.pop(context, true); // Return true to list to refresh
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Cannot Delete: ${e.toString().replaceAll("Exception:", "").trim()}',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 90,
        backgroundColor: Colors.white,
        elevation: 1,
        titleSpacing: 24,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFA01B2D).withOpacity(0.1),
              child: Text(
                _currentProduct.name.isNotEmpty ? _currentProduct.name[0] : '?',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFA01B2D),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _currentProduct.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'SKU: ${_currentProduct.sku}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Text(
                          _currentProduct.category,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Product',
            onPressed: _editProduct,
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print Label',
            onPressed: () {
              final printer = PrintingService();
              printer.printProductLabel(_currentProduct);
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'delete') {
                _deleteProduct();
              } else if (value == 'variants') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        BulkVariantScreen(templateProduct: _currentProduct),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'variants',
                child: Row(
                  children: [
                    Icon(Icons.copy, size: 20),
                    SizedBox(width: 8),
                    Text('Manage Variants'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Delete Product', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ProductDetailsContent(product: _currentProduct),
    );
  }
}

class ProductDetailsContent extends StatefulWidget {
  final Product product;
  const ProductDetailsContent({super.key, required this.product});

  @override
  State<ProductDetailsContent> createState() => _ProductDetailsContentState();
}

class _ProductDetailsContentState extends State<ProductDetailsContent> {
  late Future<List<dynamic>> _stockHistoryFuture;

  @override
  void initState() {
    super.initState();
    _stockHistoryFuture = ApiService().getStockHistory(widget.product.id!);
  }

  @override
  void didUpdateWidget(covariant ProductDetailsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id) {
      _stockHistoryFuture = ApiService().getStockHistory(widget.product.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section moved to AppBar
          LayoutBuilder(
            builder: (context, constraints) {
              // Threshold for side-by-side layout (e.g., tablet landscape/desktop)
              if (constraints.maxWidth > 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          _buildFinancialsSection(), // Moved Financials up since header is gone
                          const SizedBox(height: 24),
                          _buildDetailsSection(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(flex: 5, child: _buildStockHistorySection()),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildFinancialsSection(),
                    const SizedBox(height: 24),
                    _buildDetailsSection(),
                    const SizedBox(height: 24),
                    _buildStockHistorySection(),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Product Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Divider(),
        _buildDetailRow('Type', widget.product.type),
        _buildDetailRow('Color/Variant', widget.product.color ?? 'N/A'),
        _buildDetailRow(
          'Description',
          widget.product.description ?? 'No description',
        ),
        _buildDetailRow(
          'Reorder Level',
          '${widget.product.reorderLevel} units',
        ),
      ],
    );
  }

  Widget _buildFinancialsSection() {
    final margin = widget.product.baseSellingPrice - widget.product.costPrice;
    final marginPercent = widget.product.baseSellingPrice > 0
        ? (margin / widget.product.baseSellingPrice) * 100
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Financials',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Divider(),
        _buildDetailRow(
          'Selling Price',
          'KES ${widget.product.baseSellingPrice}',
        ),
        _buildDetailRow('Cost Price', 'KES ${widget.product.costPrice}'),
        _buildDetailRow(
          'Margin',
          'KES ${margin.toStringAsFixed(2)} (${marginPercent.toStringAsFixed(1)}%)',
        ),
        _buildDetailRow(
          'Wholesale Price',
          widget.product.wholesalePrice != null
              ? 'KES ${widget.product.wholesalePrice}'
              : 'Not Set',
        ),
        _buildDetailRow(
          'Min. Order Qty',
          '${widget.product.minWholesaleQty} units',
        ),
      ],
    );
  }

  Widget _buildStockHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Stock History',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Divider(),
        const SizedBox(height: 8),
        FutureBuilder<List<dynamic>>(
          future: _stockHistoryFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final history = snapshot.data ?? [];
            if (history.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.history, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'Current Stock: ${widget.product.stockLevel.toInt()}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No movement history found.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    color: const Color(0xFFA01B2D).withValues(alpha: 0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Current Stock',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${widget.product.stockLevel.toInt()} Units',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFA01B2D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: history.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = history[index];
                    final rawType = (item['type'] as String? ?? '')
                        .toUpperCase();
                    final refId = item['reference_id'];
                    final qty =
                        double.tryParse(item['quantity'].toString()) ?? 0.0;
                    final reason = item['reason'] ?? '-';
                    final date = item['created_at'].toString().split('T')[0];

                    String title = rawType;
                    if (rawType == 'SALE' && refId != null) {
                      title = 'Sale #$refId';
                    } else if (rawType == 'RESTOCK' && refId != null) {
                      title = 'Restock (Batch #$refId)';
                    } else if (rawType == 'RETURN' && refId != null) {
                      title = 'Return (Order #$refId)';
                    }

                    Color color = Colors.blue;
                    IconData icon = Icons.info;

                    if (rawType == 'SALE') {
                      color = Colors.red;
                      icon = Icons.shopping_cart;
                    } else if (rawType == 'RESTOCK') {
                      color = Colors.green;
                      icon = Icons.add_box;
                    } else if (rawType == 'ADJUSTMENT') {
                      color = Colors.orange;
                      icon = Icons.tune;
                    } else if (rawType == 'RETURN') {
                      color = Colors.purple;
                      icon = Icons.assignment_return;
                    }

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.1),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      title: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('$reason • $date'),
                      trailing: Text(
                        qty > 0 ? '+$qty' : '$qty',
                        style: TextStyle(
                          color: qty > 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(title, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
