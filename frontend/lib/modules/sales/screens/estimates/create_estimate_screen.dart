import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/services/api_service.dart';
import '../../../inventory/models/product_model.dart'; // Verify this path

class CreateEstimateScreen extends StatefulWidget {
  final int? estimateId; // If provided, we are editing
  const CreateEstimateScreen({super.key, this.estimateId});

  @override
  State<CreateEstimateScreen> createState() => _CreateEstimateScreenState();
}

class _CreateEstimateScreenState extends State<CreateEstimateScreen> {
  final ApiService _apiService = ApiService();
  bool _isSaving = false;
  bool _isLoadingDetails = false;

  // Form Data
  List<dynamic> _customers = [];
  Map<String, dynamic>? _selectedCustomer;
  DateTime _validUntil = DateTime.now().add(const Duration(days: 30));
  final TextEditingController _notesController = TextEditingController();

  // Items
  final List<EstimateItem> _cart = [];

  // Search
  final TextEditingController _searchController = TextEditingController();
  List<Product> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadCustomers();
    if (widget.estimateId != null) {
      await _loadEstimateDetails(widget.estimateId!);
    }
  }

  Future<void> _loadCustomers() async {
    try {
      final customers = await _apiService.getCustomers();
      setState(() {
        _customers = customers;
      });
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _loadEstimateDetails(int id) async {
    setState(() => _isLoadingDetails = true);
    try {
      final details = await _apiService.getEstimateDetails(id);

      // Populate Form
      // Customer
      if (details['customer_id'] != null) {
        try {
          final cust = _customers.firstWhere(
            (c) => c['id'] == details['customer_id'],
          );
          _selectedCustomer = cust;
        } catch (_) {
          // Customer might be deleted or not found
        }
      }

      // Notes & Date
      _notesController.text = details['notes'] ?? '';
      if (details['valid_until'] != null) {
        _validUntil = DateTime.parse(details['valid_until']);
      }

      // Items
      final items = details['items'] as List<dynamic>;
      for (final item in items) {
        _cart.add(
          EstimateItem(
            productId: item['product_id'],
            name: item['product_name'] ?? 'Unknown Item',
            unitPrice: double.tryParse(item['unit_price'].toString()) ?? 0.0,
            quantity: int.tryParse(item['quantity'].toString()) ?? 1,
          ),
        );
      }

      setState(() => _isLoadingDetails = false);
    } catch (e) {
      setState(() => _isLoadingDetails = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load details: $e')));
        Navigator.pop(context);
      }
    }
  }

  // ... (Search Methods same as before) ...

  // ... (Cart Methods same as before) ...

  // ... (Increment/Decrement same as before) ...

  // Need to duplicate these here because I'm replacing the whole top block?
  // No, I can use StartLine/EndLine carefully.
  // Actually, I'll just rewrite the save method separately if I can, but the variables are above.
  // Let's assume I need to supply the Search methods if I overwrite them.
  // The replace block below will cut off before _addToCart.

  Future<void> _searchProducts(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final products = await _apiService.getProducts(search: query);
      setState(() {
        _searchResults = products;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  void _addToCart(Product product) {
    setState(() {
      final existingIndex = _cart.indexWhere((i) => i.productId == product.id);
      if (existingIndex >= 0) {
        _cart[existingIndex].quantity++;
      } else {
        _cart.add(
          EstimateItem(
            productId: product.id!,
            name: product.name,
            unitPrice: product.baseSellingPrice,
            quantity: 1,
          ),
        );
      }
      _searchController.clear();
      _searchResults = [];
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      _cart.removeAt(index);
    });
  }

  void _incrementQty(int index) {
    setState(() {
      _cart[index].quantity++;
    });
  }

  void _decrementQty(int index) {
    setState(() {
      if (_cart[index].quantity > 1) {
        _cart[index].quantity--;
      } else {
        _removeFromCart(index);
      }
    });
  }

  double get _totalAmount =>
      _cart.fold(0, (sum, item) => sum + (item.quantity * item.unitPrice));

  Future<void> _saveEstimate() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add items to the quote')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final payload = {
        'customerId': _selectedCustomer?['id'],
        'validUntil': _validUntil.toIso8601String(),
        'notes': _notesController.text,
        'items': _cart
            .map(
              (i) => {
                'productId': i.productId,
                'quantity': i.quantity,
                'unitPrice': i.unitPrice,
              },
            )
            .toList(),
      };

      if (widget.estimateId != null) {
        await _apiService.updateEstimate(widget.estimateId!, payload);
      } else {
        await _apiService.createEstimate(payload);
      }

      if (mounted) {
        Navigator.pop(context, true); // Return success
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.estimateId != null ? 'Edit Quote' : 'New Quote',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        bottom: _isLoadingDetails
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.grey[100],
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFA01B2D),
                  ),
                ),
              )
            : null,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _saveEstimate,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check, size: 18),
              label: Text(_isSaving ? 'Saving...' : 'Save Quote'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFA01B2D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // LEFT: Unified Panel (Form + Items)
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Scrollable Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Section
                          const Text(
                            'Customer & Terms',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFA01B2D),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildHeaderForm(),
                          const SizedBox(height: 32),

                          // Items Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Items',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFA01B2D),
                                ),
                              ),
                              if (_cart.isNotEmpty)
                                Chip(
                                  label: Text('${_cart.length} Items'),
                                  backgroundColor: Colors.grey[100],
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Search Bar
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search products to add...',
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Colors.grey,
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              suffixIcon: _isSearching
                                  ? Transform.scale(
                                      scale: 0.5,
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : null,
                            ),
                            onChanged: (val) {
                              Future.delayed(
                                const Duration(milliseconds: 500),
                                () {
                                  if (val == _searchController.text) {
                                    _searchProducts(val);
                                  }
                                },
                              );
                            },
                          ),

                          // Search Results
                          if (_searchResults.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _searchResults.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(height: 1),
                                itemBuilder: (ctx, i) {
                                  final p = _searchResults[i];
                                  return ListTile(
                                    title: Text(
                                      p.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Stock: ${p.stockLevel} • KES ${p.baseSellingPrice}',
                                    ),
                                    trailing: const Icon(
                                      Icons.add_circle_outline,
                                      color: Color(0xFFA01B2D),
                                    ),
                                    onTap: () {
                                      if (p.id != null) {
                                        _addToCart(p);
                                      }
                                    },
                                  );
                                },
                              ),
                            ),

                          const SizedBox(height: 24),

                          // Item List (Cart)
                          if (_cart.isEmpty)
                            Container(
                              height: 200,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  // style: BorderStyle.dashed, // Not supported directly
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.shopping_basket_outlined,
                                    size: 48,
                                    color: Colors.grey[300],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No items added yet',
                                    style: TextStyle(color: Colors.grey[400]),
                                  ),
                                ],
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _cart.length,
                              separatorBuilder: (ctx, i) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (ctx, i) {
                                final item = _cart[i];
                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50], // Slight tint
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey[200]!,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.shopping_bag_outlined,
                                          color: Colors.deepPurple,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Text(
                                              'KES ${item.unitPrice}',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Qty Control
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.remove,
                                              size: 18,
                                            ),
                                            onPressed: () => _decrementQty(i),
                                            style: IconButton.styleFrom(
                                              backgroundColor: Colors.white,
                                            ),
                                          ),
                                          SizedBox(
                                            width: 40,
                                            child: Center(
                                              child: Text(
                                                '${item.quantity}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.add,
                                              size: 18,
                                            ),
                                            onPressed: () => _incrementQty(i),
                                            style: IconButton.styleFrom(
                                              backgroundColor: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        'KES ${(item.quantity * item.unitPrice).toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                        ),
                                        onPressed: () => _removeFromCart(i),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // RIGHT: Summary
          Container(
            width: 350,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(left: BorderSide(color: Colors.grey[200]!)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(-4, 0),
                ),
              ],
            ),
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quote Summary',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                _buildSummaryRow('Items', '${_cart.length}'),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Divider(),
                ),
                _buildSummaryRow(
                  'Total',
                  'KES ${_totalAmount.toStringAsFixed(2)}',
                  isBold: true,
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveEstimate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA01B2D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      widget.estimateId != null
                          ? 'Update Quote'
                          : 'Generate Quote',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderForm() {
    return Column(
      children: [
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Select Customer',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Map<String, dynamic>>(
              isDense: true,
              value: _selectedCustomer,
              items: _customers.map((c) {
                return DropdownMenuItem<Map<String, dynamic>>(
                  value: c,
                  child: Text(c['name'] ?? 'Unknown'),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedCustomer = val),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes / Terms',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _validUntil,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => _validUntil = date);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Valid Until',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    DateFormat('dd MMM yyyy').format(_validUntil),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
              color: isBold ? const Color(0xFFA01B2D) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class EstimateItem {
  final int productId;
  final String name;
  final double unitPrice;
  int quantity;

  EstimateItem({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
  });
}
