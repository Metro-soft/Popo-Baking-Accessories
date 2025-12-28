import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../inventory/models/product_model.dart';
import 'widgets/customer_selector.dart';
import 'widgets/payment_modal.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<Product> _allProducts = [];
  bool _isLoading = false;

  // Cart: List of {product, quantity, type, unitPrice, serial, deposit}
  final List<Map<String, dynamic>> _cart = [];

  // Customer
  Map<String, dynamic>? _selectedCustomer;

  // New State for Phase 3
  bool _isReturnMode = false;
  double _discountAmount = 0.0;
  String _discountReason = '';

  // Tabs
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final prods = await _apiService.getProducts();
      setState(() => _allProducts = prods);
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

  // Calculations
  double get _subtotal {
    return _cart.fold(0.0, (sum, item) {
      return sum + (item['quantity'] * item['unitPrice']);
    });
  }

  double get _depositTotal {
    return _cart.fold(0.0, (sum, item) {
      return sum + (item['deposit'] ?? 0.0);
    });
  }

  double get _grandTotal {
    double total = _subtotal + _depositTotal;
    // For net returns (negative total), discount logic is weird. Let's assume positive discount on positive total.
    if (total > 0) {
      total -= _discountAmount;
      if (total < 0) total = 0;
    }
    return total;
  }

  // Actions
  void _addToCart(Product p, {String type = 'retail'}) {
    // If Asset, show Dialog for Serial & Deposit
    if (p.type == 'asset_rental' || type == 'asset_rental') {
      _showRentalDialog(p);
      return;
    }

    // Retail/Print check if already in cart
    final index = _cart.indexWhere(
      (item) => item['product'].id == p.id && item['type'] == type,
    );
    if (index >= 0) {
      setState(() {
        _cart[index]['quantity'] += _isReturnMode ? -1 : 1;
      });
    } else {
      setState(() {
        _cart.add({
          'product': p,
          'quantity': _isReturnMode ? -1 : 1,
          'type': type,
          'unitPrice': p.baseSellingPrice,
          'deposit': 0.0,
        });
      });
    }
  }

  void _showRentalDialog(Product p) {
    String serial = '';
    double deposit = p.rentalDeposit ?? 0.0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rent ${p.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Serial / ID Number',
              ),
              onChanged: (v) => serial = v,
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(labelText: 'Deposit Amount'),
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: deposit.toString()),
              onChanged: (v) => deposit = double.tryParse(v) ?? 0.0,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _cart.add({
                  'product': p,
                  'quantity': 1,
                  'type': 'asset_rental',
                  'unitPrice': p.baseSellingPrice,
                  'serial': serial, // Should validate not empty ideally
                  'deposit': deposit,
                });
              });
              Navigator.pop(ctx);
            },
            child: const Text('Add to Cart'),
          ),
        ],
      ),
    );
  }

  void _showDiscountDialog() {
    final amountController = TextEditingController(
      text: _discountAmount.toString(),
    );
    final reasonController = TextEditingController(text: _discountReason);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apply Discount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (KES)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Reason (Optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _discountAmount = double.tryParse(amountController.text) ?? 0.0;
                _discountReason = reasonController.text;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Future<void> _holdSale() async {
    await _submitTransaction(isHold: true);
  }

  void _processPayment() {
    if (_cart.isEmpty) return; // Add snackbar

    if (_isReturnMode && _grandTotal < 0) {
      // Refund scenario - Skip payment modal maybe? Or record "Cash Out".
      // For MVP, just confirm refund.
      _submitTransaction(); // No payments needed if full refund? Or need to specify method of refund?
      // Let's assume we still pick "Cash" to show we gave cash back.
      // So proceed to Modal.
    }

    showDialog(
      context: context,
      builder: (ctx) => PaymentModal(
        totalAmount: _grandTotal
            .abs(), // Show positive amount for payment/refund entry
        customer: _selectedCustomer,
        onConfirm: (payments) => _submitTransaction(payments: payments),
      ),
    );
  }

  Future<void> _submitTransaction({
    List<Map<String, dynamic>>? payments,
    bool isHold = false,
  }) async {
    // Construct Payload
    final payload = {
      'customerId': _selectedCustomer?['id'],
      'isHold': isHold,
      'discountAmount': _discountAmount,
      'discountReason': _discountReason.isNotEmpty ? _discountReason : 'Manual',
      'items': _cart
          .map(
            (item) => {
              'productId': (item['product'] as Product).id,
              'quantity': item['quantity'],
              'type': item['type'],
              'unitPrice': item['unitPrice'],
              'serialNumber': item['serial'],
              'depositAmount': item['deposit'],
            },
          )
          .toList(),
      'payments': payments ?? [],
    };

    setState(() => _isLoading = true);
    try {
      await _apiService.processTransaction(payload);
      if (mounted) {
        setState(() {
          _cart.clear();
          _selectedCustomer = null;
          _discountAmount = 0;
          _isReturnMode = false;
        });

        if (!isHold) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Success'),
              content: const Text('Transaction Complete!'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sale Held Successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Views
  Widget _buildProductGrid(String typeFilter) {
    // Filter logic:
    // Retail -> type='retail' or 'raw_material' (if selling raw)
    // Rental -> type='asset_rental'
    // Print -> type='service_print'

    final products = _allProducts.where((p) {
      if (typeFilter == 'retail') {
        return p.type == 'retail' || p.type == 'raw_material';
      }
      if (typeFilter == 'rental') {
        return p.type == 'asset_rental';
      }
      if (typeFilter == 'print') {
        return p.type == 'service_print';
      }
      return false;
    }).toList();

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, // Desktop optimized
        childAspectRatio: 0.8,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: products.length,
      itemBuilder: (ctx, i) {
        final p = products[i];
        return InkWell(
          onTap: () => _addToCart(
            p,
            type: typeFilter == 'print' ? 'service_print' : p.type,
          ),
          child: Card(
            elevation: 2,
            color: typeFilter == 'rental' ? Colors.blue[50] : Colors.white,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  typeFilter == 'print'
                      ? Icons.print
                      : (p.type == 'asset_rental'
                            ? Icons.chair
                            : Icons.shopping_bag),
                  size: 40,
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 10),
                Text(
                  p.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('KES ${p.baseSellingPrice}'),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POS & Checkout'),
        actions: [
          Row(
            children: [
              const Text('Return Mode', style: TextStyle(fontSize: 12)),
              Switch(
                value: _isReturnMode,
                onChanged: (val) {
                  setState(() {
                    _isReturnMode = val;
                    // Optional: Clear cart or warn?
                    // Let's keep cart but future adds will be negative.
                  });
                },
                activeTrackColor: Colors.redAccent,
                activeThumbColor: Colors.red,
              ),
            ],
          ),
          const SizedBox(width: 16),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.shopping_bag), text: 'RETAIL'),
            Tab(icon: Icon(Icons.chair), text: 'RENTALS'),
            Tab(icon: Icon(Icons.print), text: 'PRINTING'),
          ],
        ),
      ),
      body: Row(
        children: [
          // LEFT: Product Grid
          Expanded(
            flex: 6,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProductGrid('retail'),
                _buildProductGrid('rental'),
                _buildProductGrid('print'),
              ],
            ),
          ),

          // RIGHT: Cart Sidebar
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: Colors.grey[300]!)),
                color: Colors.grey[50],
              ),
              child: Column(
                children: [
                  // Customer Header
                  CustomerSelector(
                    onCustomerSelected: (c) =>
                        setState(() => _selectedCustomer = c),
                  ),
                  const Divider(),

                  // Cart Items
                  Expanded(
                    child: _cart.isEmpty
                        ? const Center(
                            child: Text(
                              'Cart Empty',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _cart.length,
                            itemBuilder: (ctx, i) {
                              final item = _cart[i];
                              final p = item['product'] as Product;
                              return ListTile(
                                title: Text(p.name),
                                subtitle: item['type'] == 'asset_rental'
                                    ? Text('Deposit: ${item['deposit']}')
                                    : Text('@ ${item['unitPrice']}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('x${item['quantity']}'),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.red,
                                      ),
                                      onPressed: () =>
                                          setState(() => _cart.removeAt(i)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  // Footer Totals
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: _isReturnMode ? Colors.red[50] : Colors.white,
                    child: Column(
                      children: [
                        // Return Mode Toggle
                        if (_isReturnMode)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(8),
                            color: Colors.red,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.warning, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'RETURN MODE ACTIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal:'),
                            Text('KES ${_subtotal.toStringAsFixed(2)}'),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Deposit (Refundable):'),
                            Text('KES ${_depositTotal.toStringAsFixed(2)}'),
                          ],
                        ),
                        // Discount Row
                        InkWell(
                          onTap: _showDiscountDialog,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Discount (Tap to edit):',
                                style: TextStyle(color: Colors.blue),
                              ),
                              Text(
                                '- KES ${_discountAmount.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.blue),
                              ),
                            ],
                          ),
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TOTAL TO PAY:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'KES ${_grandTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: OutlinedButton(
                                onPressed: _holdSale,
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(50),
                                ),
                                child: const Text('HOLD'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _processPayment,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(50),
                                  backgroundColor: _isReturnMode
                                      ? Colors.red
                                      : Colors.deepPurple,
                                  foregroundColor: Colors.white,
                                ),
                                child: _isLoading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                    : Text(
                                        _isReturnMode
                                            ? 'PROCESS RETURN'
                                            : 'CHECKOUT',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
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
            ),
          ),
        ],
      ),
    );
  }
}
