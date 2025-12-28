import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../models/product_model.dart';

class ReceiveStockScreen extends StatefulWidget {
  const ReceiveStockScreen({super.key});

  @override
  State<ReceiveStockScreen> createState() => _ReceiveStockScreenState();
}

class _ReceiveStockScreenState extends State<ReceiveStockScreen> {
  final _formKey = GlobalKey<FormState>();

  final ApiService _apiService = ApiService();

  List<dynamic> _suppliers = [];
  List<dynamic> _branches = [];
  List<Product> _products = [];

  // Form Fields
  int? _selectedSupplierId;
  int? _selectedBranchId; // Defaults to Head Office usually
  final TextEditingController _transportCostCtrl = TextEditingController(
    text: '0',
  );
  final TextEditingController _packagingCostCtrl = TextEditingController(
    text: '0',
  );

  // Items Cart
  final List<Map<String, dynamic>> _cart = [];

  // Item Entry State
  Product? _currentItem;
  final TextEditingController _qtyCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  DateTime? _expiryDate;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final s = await _apiService.getSuppliers();
      final p = await _apiService.getProducts();
      final b = await _apiService.getBranches();

      setState(() {
        _suppliers = s;
        _products = p;
        _branches = b;
        // Default to Head Office / Warehouse if exists (usually ID 1)
        if (_branches.isNotEmpty) {
          final warehouse = _branches.firstWhere(
            (br) =>
                br['name'].toString().toLowerCase().contains('head') ||
                br['name'].toString().toLowerCase().contains('central'),
            orElse: () => _branches.first,
          );
          _selectedBranchId = warehouse['id'];
        }
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

  void _addItem() {
    if (_currentItem == null ||
        _qtyCtrl.text.isEmpty ||
        _priceCtrl.text.isEmpty) {
      return;
    }
    final qty = int.tryParse(_qtyCtrl.text);
    final price = double.tryParse(_priceCtrl.text);

    if (qty == null || qty <= 0 || price == null || price < 0) return;

    setState(() {
      _cart.add({
        'productId': _currentItem!.id,
        'productName': _currentItem!.name,
        'quantity': qty,
        'unitPrice': price,
        'expiryDate': _expiryDate?.toIso8601String(),
      });
      // Reset Item Fields
      _currentItem = null;
      _qtyCtrl.clear();
      _priceCtrl.clear();
      _expiryDate = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSupplierId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select Supplier')));
      return;
    }
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Add Items first')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final payload = {
        'supplierId': _selectedSupplierId,
        'branchId': _selectedBranchId,
        'transportCost': double.tryParse(_transportCostCtrl.text) ?? 0,
        'packagingCost': double.tryParse(_packagingCostCtrl.text) ?? 0,
        'items': _cart,
      };

      await _apiService.submitStockEntry(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock Received Successfully!')),
        );
        Navigator.pop(context); // Go back or clear form
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receive Stock (PO)')),
      body: _isLoading && _products.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Header: Supplier & Branch
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                key: ValueKey(_selectedSupplierId),
                                initialValue: _selectedSupplierId,
                                decoration: const InputDecoration(
                                  labelText: 'Supplier',
                                  border: OutlineInputBorder(),
                                ),
                                items: _suppliers
                                    .map(
                                      (s) => DropdownMenuItem<int>(
                                        value: s['id'],
                                        child: Text(s['name']),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedSupplierId = v),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                key: ValueKey(_selectedBranchId),
                                initialValue: _selectedBranchId,
                                decoration: const InputDecoration(
                                  labelText: 'Receive To Branch',
                                  border: OutlineInputBorder(),
                                ),
                                items: _branches
                                    .map(
                                      (b) => DropdownMenuItem<int>(
                                        value: b['id'],
                                        child: Text(b['name']),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedBranchId = v),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Extra Costs
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _transportCostCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Transport Cost',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _packagingCostCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Packaging Cost',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 32),

                        // Add Item Section
                        const Text(
                          'Add Items',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<Product>(
                                key: ValueKey(_currentItem),
                                initialValue: _currentItem,
                                decoration: const InputDecoration(
                                  labelText: 'Product',
                                ),
                                items: _products
                                    .map(
                                      (p) => DropdownMenuItem(
                                        value: p,
                                        child: Text(p.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _currentItem = v),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: _qtyCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Qty',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: _priceCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Cost',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle,
                                color: Colors.green,
                                size: 32,
                              ),
                              onPressed: _addItem,
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        // Cart List
                        if (_cart.isNotEmpty)
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            height: 200,
                            child: ListView.separated(
                              itemCount: _cart.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (ctx, i) {
                                final item = _cart[i];
                                return ListTile(
                                  dense: true,
                                  title: Text(item['productName']),
                                  subtitle: Text(
                                    '${item['quantity']} units @ ${item['unitPrice']}',
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, size: 16),
                                    onPressed: () =>
                                        setState(() => _cart.removeAt(i)),
                                  ),
                                );
                              },
                            ),
                          )
                        else
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Text('No Items Added'),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Footer
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text('RECEIVE STOCK'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
