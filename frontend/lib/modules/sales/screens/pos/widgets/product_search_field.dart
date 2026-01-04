import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/api_service.dart';
import '../../../../inventory/models/product_model.dart';
import '../../../providers/sales_provider.dart';

class ProductSearchField extends StatefulWidget {
  final VoidCallback? onBrowseCatalog;

  const ProductSearchField({super.key, this.onBrowseCatalog});

  @override
  State<ProductSearchField> createState() => _ProductSearchFieldState();
}

class _ProductSearchFieldState extends State<ProductSearchField> {
  final ApiService _apiService = ApiService();
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _controller = TextEditingController();

  List<Product> _allProducts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    // We cache products locally for the autocomplete to be fast.
    // In a real large app, we might search server-side on type.
    setState(() => _isLoading = true);
    try {
      final prods = await _apiService.getProducts();
      if (mounted) setState(() => _allProducts = prods);
    } catch (e) {
      debugPrint('Error loading products for search: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSelected(Product product) {
    context.read<SalesProvider>().addItem(product);
    _controller.clear();
    // Keep focus for rapid entry? Or explicit tab?
    // Usually rapid entry is better.
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            Expanded(
              child: Autocomplete<Product>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<Product>.empty();
                  }
                  final query = textEditingValue.text.toLowerCase();
                  return _allProducts.where((Product option) {
                    return option.name.toLowerCase().contains(query) ||
                        option.sku.toLowerCase().contains(query);
                  });
                },
                displayStringForOption: (Product option) => option.name,
                onSelected: _onSelected,
                fieldViewBuilder:
                    (
                      context,
                      textEditingController,
                      focusNode,
                      onFieldSubmitted,
                    ) {
                      // Link our internal controller if needed, but Autocomplete manages one.
                      // We'll just hook into the focus node.
                      return TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        onSubmitted: (val) {
                          // Handle enter if not selected from list?
                          onFieldSubmitted();
                        },
                        decoration: InputDecoration(
                          hintText: 'Search Product (Name or SKU)...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      );
                    },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width:
                            constraints.maxWidth -
                            (widget.onBrowseCatalog != null
                                ? 150
                                : 0), // Adjust width based on parent
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final Product option = options.elementAt(index);
                            final isOutOfStock =
                                option.stockLevel <= 0 &&
                                option.type == 'retail';
                            return ListTile(
                              title: Text(
                                option.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text('SKU: ${option.sku}'),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'KES ${option.baseSellingPrice}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                  if (option.type == 'retail')
                                    Text(
                                      '${option.stockLevel.toInt()} in stock',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isOutOfStock
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                    ),
                                ],
                              ),
                              onTap: () => onSelected(option),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (widget.onBrowseCatalog != null) ...[
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: widget.onBrowseCatalog,
                icon: const Icon(Icons.grid_view),
                label: const Text('Catalog'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 18,
                    horizontal: 20,
                  ),
                  side: BorderSide(color: Colors.grey.shade300),
                  backgroundColor: Colors.white,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
