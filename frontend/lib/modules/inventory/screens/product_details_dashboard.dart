import 'package:flutter/material.dart';
import '../models/product_model.dart';
import 'bulk_variant_screen.dart';
import 'add_product_screen.dart';
import '../../core/services/printing_service.dart';
import '../../core/services/api_service.dart';

class ProductDetailsDashboard extends StatefulWidget {
  final Product product;
  final Function(Product)? onEdit;
  final VoidCallback? onDelete;
  const ProductDetailsDashboard({
    super.key,
    required this.product,
    this.onEdit,
    this.onDelete,
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

  @override
  void didUpdateWidget(covariant ProductDetailsDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id) {
      setState(() {
        _currentProduct = widget.product;
      });
      // Also refresh from API to ensure fresh data
      _refreshProduct();
    }
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

          if (widget.onDelete != null) {
            // Desktop/Split View mode: Notify parent to clear selection
            widget.onDelete!();
          } else {
            // Mobile/Pushed View mode: Pop the route
            Navigator.pop(context, true);
          }
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
    // Use DefaultTabController for 3 Tabs: Details, Financials, History
    return DefaultTabController(
      length: 3,
      child: Scaffold(
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
                backgroundColor: const Color(0xFFA01B2D).withValues(alpha: 0.1),
                child: Text(
                  _currentProduct.name.isNotEmpty
                      ? _currentProduct.name[0]
                      : '?',
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
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
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
                      Text(
                        'Delete Product',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
          ],
          bottom: const TabBar(
            labelColor: Color(0xFFA01B2D),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFFA01B2D),
            tabs: [
              Tab(text: 'Details', icon: Icon(Icons.info_outline)),
              Tab(text: 'Financials', icon: Icon(Icons.attach_money)),
              Tab(text: 'Stock History', icon: Icon(Icons.history)),
            ],
          ),
        ),
        body: ProductDetailsContent(product: _currentProduct),
        floatingActionButton: FloatingActionButton(
          onPressed: _editProduct,
          backgroundColor: const Color(0xFFA01B2D),
          tooltip: 'Edit Product',
          child: const Icon(Icons.edit, color: Colors.white),
        ),
      ),
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
    // TabBarView must match the DefaultTabController length (3)
    return TabBarView(
      children: [
        // Tab 1: Details
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _buildDetailsSection(),
        ),

        // Tab 2: Financials
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _buildFinancialsSection(),
        ),

        // Tab 3: History
        _buildStockHistorySection(),
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
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Basic Information',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildDetailRow('Product Name', widget.product.name),
                const Divider(),
                _buildDetailRow('SKU Code', widget.product.sku),
                const Divider(),
                _buildDetailRow('Category', widget.product.category),
                const Divider(),
                _buildDetailRow('Type', widget.product.type),
                const Divider(),
                _buildDetailRow('Color/Variant', widget.product.color ?? 'N/A'),
                const Divider(),
                _buildDetailRow(
                  'Description',
                  widget.product.description ?? 'No description',
                ),
                const Divider(),
                _buildDetailRow(
                  'Reorder Level',
                  '${widget.product.reorderLevel} units',
                ),
              ],
            ),
          ),
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
          'Pricing & Margins',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildDetailRow(
                  'Selling Price',
                  'KES ${widget.product.baseSellingPrice}',
                ),
                const Divider(),
                _buildDetailRow(
                  'Cost Price',
                  'KES ${widget.product.costPrice}',
                ),
                const Divider(),
                _buildDetailRow(
                  'Unit Margin',
                  'KES ${margin.toStringAsFixed(2)}',
                ),
                const Divider(),
                _buildDetailRow(
                  'Margin %',
                  '${marginPercent.toStringAsFixed(1)}%',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Wholesale Configuration',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildDetailRow(
                  'Wholesale Price',
                  widget.product.wholesalePrice != null
                      ? 'KES ${widget.product.wholesalePrice}'
                      : 'Not Set',
                ),
                const Divider(),
                _buildDetailRow(
                  'Min. Order Qty',
                  '${widget.product.minWholesaleQty} units',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStockHistorySection() {
    return SingleChildScrollView(
      // Make full tab scrollable
      child: Column(
        children: [
          // 1. New Section: Branch Stock Distribution
          FutureBuilder<List<dynamic>>(
            future: ApiService().getStockByBranch(widget.product.id!),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final branches = snapshot.data!;
              return Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Stock by Branch',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...branches.map(
                      (b) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.blue.shade50,
                                  child: Icon(
                                    Icons.store,
                                    size: 16,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  b['branch_name'] ?? 'Unknown Branch',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${b['stock'] ?? 0}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const Divider(thickness: 8, color: Color(0xFFF5F5F5)),

          // 2. Existing History (Timeline)
          FutureBuilder<List<dynamic>>(
            future: _stockHistoryFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final history = snapshot.data ?? [];

              return Column(
                children: [
                  // Sticky Header for Current Stock
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    color: Colors.white,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Movement Timeline',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          // Total System Stock
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFA01B2D,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Total: ${widget.product.stockLevel.toInt()}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFA01B2D),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // List
                  history.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(48.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.history,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No movement history found.',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap:
                              true, // Important for SingleChildScrollView
                          physics:
                              const NeverScrollableScrollPhysics(), // Scroll parent
                          padding: const EdgeInsets.all(8),
                          itemCount: history.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = history[index];
                            final rawType = (item['type'] as String? ?? '')
                                .toUpperCase();
                            final refId = item['reference_id'];
                            final qty =
                                double.tryParse(item['quantity'].toString()) ??
                                0.0;
                            final reason = item['reason'] ?? '-';
                            final date = item['created_at'].toString().split(
                              'T',
                            )[0];

                            String title = rawType;
                            if (rawType == 'SALE' && refId != null) {
                              title = 'Sale #$refId';
                            } else if (rawType == 'RESTOCK' && refId != null) {
                              title = 'Restock (Batch #$refId)';
                            } else if (rawType == 'RETURN' && refId != null) {
                              title = 'Return (Order #$refId)';
                            } else if (rawType == 'TRANSFER_IN') {
                              title = 'Transfer In (From Branch)';
                            } else if (rawType == 'TRANSFER_OUT') {
                              title = 'Transfer Out (To Branch)';
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
                            } else if (rawType == 'TRANSFER_IN') {
                              color = Colors.teal;
                              icon = Icons.arrow_circle_down; // Incoming
                            } else if (rawType == 'TRANSFER_OUT') {
                              color = Colors.blueGrey;
                              icon = Icons.arrow_circle_up; // Outgoing
                            }

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: color.withValues(alpha: 0.1),
                                child: Icon(icon, color: color, size: 20),
                              ),
                              title: Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
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
      ),
    );
  }
}
