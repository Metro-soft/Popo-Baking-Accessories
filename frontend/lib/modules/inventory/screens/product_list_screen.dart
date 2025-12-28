import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../models/product_model.dart';
import 'add_product_screen.dart';
import 'product_details_dashboard.dart';

import 'scanner_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final ApiService _apiService = ApiService();
  List<Product> _products = [];
  bool _isLoading = false;

  final TextEditingController _searchController = TextEditingController();
  List<Product> _filteredProducts = [];
  String _searchQuery = '';

  String _selectedType = 'all';
  List<String> _categories = ['All'];
  String _selectedCategory = 'All';
  Product? _selectedProduct;
  bool _showForm = false;
  Product? _formProduct;

  // Grouping State
  Map<String, List<Product>> _groupedProducts = {};
  bool _isGrouped = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      final cats = await _apiService.getCategories();
      if (mounted) {
        setState(() {
          _categories = ['All', ...cats];
        });
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final products = await _apiService.getProducts();
      setState(() {
        _products = products;
        _applyFilters(); // Initial filter
      });
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

  void _filterProducts(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _applyFilters() {
    setState(() {
      // 1. Filter first
      List<Product> temp = _products.where((p) {
        final q = _searchQuery.toLowerCase();
        final matchSearch =
            p.name.toLowerCase().contains(q) ||
            p.sku.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q);

        bool matchType = true;
        if (_selectedType != 'all') {
          matchType = p.type == _selectedType;
        }

        bool matchCategory = true;
        if (_selectedCategory != 'All') {
          matchCategory = p.category == _selectedCategory;
        }

        return matchSearch && matchType && matchCategory;
      }).toList();

      _filteredProducts = temp;

      // 2. Group logic
      if (_isGrouped) {
        _groupedProducts = {};
        for (var p in temp) {
          if (!_groupedProducts.containsKey(p.name)) {
            _groupedProducts[p.name] = [];
          }
          _groupedProducts[p.name]!.add(p);
        }
      }
    });
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );

    if (result != null && result is String) {
      _searchController.text = result;
      _filterProducts(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scanned: $result'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Management'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadProducts),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 900) {
            // DESKTOP: Split View
            return Row(
              children: [
                // Left Pane: List
                Expanded(
                  flex: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: _buildListContent(isDesktop: true),
                  ),
                ),
                // Right Pane: Details
                Expanded(
                  flex: 6,
                  child: _showForm
                      ? AddProductScreen(
                          product: _formProduct,
                          onCancel: () {
                            setState(() {
                              _showForm = false;
                              _formProduct = null;
                            });
                          },
                          onSuccess: () {
                            setState(() {
                              _showForm = false;
                              _formProduct = null;
                            });
                            _loadProducts();
                          },
                        )
                      : _selectedProduct != null
                      ? ProductDetailsDashboard(
                          product: _selectedProduct!,
                          onEdit: (p) {
                            setState(() {
                              _showForm = true;
                              _formProduct = p;
                            });
                          },
                        )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Select a product to view details',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            );
          } else {
            // MOBILE: List Only
            return _buildListContent();
          }
        },
      ),
      floatingActionButton: MediaQuery.of(context).size.width > 900
          ? null
          : FloatingActionButton(
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

  Widget _buildListContent({bool isDesktop = false}) {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search',
                    hintText: 'Name, SKU...',
                    prefixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: _scanBarcode,
                      tooltip: 'Scan Barcode',
                    ),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              _filterProducts('');
                            },
                            icon: const Icon(Icons.clear),
                          )
                        : null,
                  ),
                  onChanged: _filterProducts,
                ),
              ),
              const SizedBox(width: 8),
              // Type Dropdown
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedType,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Types')),
                      DropdownMenuItem(value: 'retail', child: Text('Retail')),
                      DropdownMenuItem(
                        value: 'service_print',
                        child: Text('Service'),
                      ),
                      DropdownMenuItem(
                        value: 'asset_rental',
                        child: Text('Rentals'),
                      ),
                      DropdownMenuItem(
                        value: 'raw_material',
                        child: Text('Raw Mat.'),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedType = val ?? 'all';
                        _applyFilters();
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        const Divider(),

        // Add Button Row
        // Add Button & Filter Row
        if (isDesktop)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  height: 32,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showForm = true;
                        _formProduct = null;
                        _selectedProduct = null;
                      });
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text(
                      'Add New',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA01B2D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.filter_list,
                    color: _selectedCategory == 'All'
                        ? Colors.grey
                        : const Color(0xFFA01B2D),
                  ),
                  tooltip: 'Filter Category',
                  onSelected: (val) {
                    setState(() {
                      _selectedCategory = val;
                      _applyFilters();
                    });
                  },
                  itemBuilder: (context) {
                    return [
                      const PopupMenuItem(
                        value: 'All',
                        child: Text('All Categories'),
                      ),
                      ..._categories
                          .where((c) => c != 'All')
                          .map(
                            (c) => PopupMenuItem(
                              value: c,
                              child: Text(
                                c,
                                style: TextStyle(
                                  fontWeight: c == _selectedCategory
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: c == _selectedCategory
                                      ? const Color(0xFFA01B2D)
                                      : null,
                                ),
                              ),
                            ),
                          ),
                    ];
                  },
                ),
              ],
            ),
          ),

        // Stats
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Row(
            children: [
              Text(
                '${_filteredProducts.length} Results',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),

              Row(
                children: [
                  const Text('Group Variants', style: TextStyle(fontSize: 12)),
                  Switch(
                    value: _isGrouped,
                    onChanged: (val) {
                      setState(() {
                        _isGrouped = val;
                        _applyFilters();
                      });
                    },
                    activeThumbColor: const Color(0xFFA01B2D),
                  ),
                ],
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _isGrouped
              ? _buildGroupedList(isDesktop)
              : _buildFlatList(isDesktop),
        ),
      ],
    );
  }

  // Helper for Flat List
  Widget _buildFlatList(bool isDesktop) {
    return ListView.separated(
      itemCount: _filteredProducts.length,
      separatorBuilder: (ctx, i) => const Divider(height: 1),
      itemBuilder: (ctx, i) =>
          _buildProductItem(_filteredProducts[i], isDesktop: isDesktop),
    );
  }

  // Helper for Grouped List
  Widget _buildGroupedList(bool isDesktop) {
    final keys = _groupedProducts.keys.toList();
    return ListView.builder(
      itemCount: keys.length,
      itemBuilder: (ctx, i) {
        final name = keys[i];
        final variants = _groupedProducts[name]!;
        final first = variants.first;

        return ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFA01B2D).withValues(alpha: 0.1),
            child: Text(
              '${variants.length}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFA01B2D),
              ),
            ),
          ),
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('${variants.length} Variants • ${first.category}'),
          children: variants
              .map(
                (p) =>
                    _buildProductItem(p, isVariant: true, isDesktop: isDesktop),
              )
              .toList(),
        );
      },
    );
  }

  // Reusable Product Tile
  Widget _buildProductItem(
    Product p, {
    bool isVariant = false,
    bool isDesktop = false,
  }) {
    final isSelected = _selectedProduct?.id == p.id;
    return Container(
      color: isDesktop && isSelected
          ? const Color(0xFFA01B2D).withValues(alpha: 0.05)
          : null,
      child: ListTile(
        contentPadding: isVariant
            ? const EdgeInsets.only(left: 32, right: 16)
            : null,
        leading: isVariant
            ? const Icon(Icons.subdirectory_arrow_right, size: 16)
            : CircleAvatar(
                backgroundColor: _getTypeColor(p.type).withValues(alpha: 0.2),
                child: Text(
                  p.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: _getTypeColor(p.type),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
        title: Text(
          isVariant ? (p.color ?? 'Variant') : p.name,
          style: TextStyle(
            fontWeight: isVariant ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${p.sku} • ${p.category}',
              style: const TextStyle(fontSize: 12),
            ),
            if (p.color != null && !isVariant)
              Text(
                'Color: ${p.color}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),

            const SizedBox(height: 4),
            // Stock Status Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getStockColor(
                  p.stockLevel,
                  p.reorderLevel,
                ).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _getStockColor(p.stockLevel, p.reorderLevel),
                ),
              ),
              child: Text(
                'Stock: ${p.stockLevel.toInt()}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _getStockColor(p.stockLevel, p.reorderLevel),
                ),
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'KES ${p.baseSellingPrice.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (p.wholesalePrice != null)
              Text(
                'WS: ${p.wholesalePrice}',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
          ],
        ),
        onTap: () {
          if (isDesktop) {
            setState(() {
              _selectedProduct = p;
            });
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailsDashboard(product: p),
              ),
            ).then((_) => _loadProducts());
          }
        },
      ),
    );
  }

  Color _getTypeColor(String type) {
    if (type == 'retail') return Colors.green;
    if (type == 'asset_rental') return Colors.orange;
    return Colors.blue;
  }

  Color _getStockColor(double stock, int reorder) {
    if (stock <= 0) return Colors.red;
    if (stock <= reorder) return Colors.amber;
    return Colors.green;
  }
}
