import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../models/product_model.dart'; // Assuming this exists

class StockTransferScreen extends StatefulWidget {
  const StockTransferScreen({super.key});

  @override
  State<StockTransferScreen> createState() => _StockTransferScreenState();
}

class _StockTransferScreenState extends State<StockTransferScreen> {
  final ApiService _apiService = ApiService();

  List<dynamic> _branches = [];
  List<Product> _products = [];

  int? _selectedFromBranch;
  int? _selectedToBranch;
  Product? _selectedProduct;
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // Transfer Cart
  final List<Map<String, dynamic>> _transferItems = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final branches = await _apiService.getBranches();
      final products = await _apiService.getProducts();
      setState(() {
        _branches = branches;
        _products = products;
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
    if (_selectedProduct == null || _quantityController.text.isEmpty) return;
    final qty = int.tryParse(_quantityController.text);
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid Quantity')));
      return;
    }

    setState(() {
      _transferItems.add({
        'productId': _selectedProduct!.id,
        'productName': _selectedProduct!.name,
        'quantity': qty,
      });
      _selectedProduct = null;
      _quantityController.clear();
    });
  }

  Future<void> _submitTransfer() async {
    if (_selectedFromBranch == null || _selectedToBranch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select Source and Destination Branches')),
      );
      return;
    }
    if (_selectedFromBranch == _selectedToBranch) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Source and Destination cannot be the same'),
        ),
      );
      return;
    }
    if (_transferItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No items to transfer')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _apiService.createStockTransfer(
        _selectedFromBranch!,
        _selectedToBranch!,
        _transferItems,
        _notesController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transfer Successful!')));
        setState(() {
          _transferItems.clear();
          _notesController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Transfer Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Stock Transfer')),
      body: _isLoading && _branches.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Branch Selection
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          key: ValueKey(_selectedFromBranch),
                          initialValue: _selectedFromBranch,
                          decoration: const InputDecoration(
                            labelText: 'From Branch',
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
                          onChanged: (val) =>
                              setState(() => _selectedFromBranch = val),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.arrow_forward),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          key: ValueKey(_selectedToBranch),
                          initialValue: _selectedToBranch,
                          decoration: const InputDecoration(
                            labelText: 'To Branch',
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
                          onChanged: (val) =>
                              setState(() => _selectedToBranch = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Item Entry
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<Product>(
                          key: ValueKey(_selectedProduct),
                          initialValue: _selectedProduct,
                          decoration: const InputDecoration(
                            labelText: 'Select Product',
                            border: OutlineInputBorder(),
                          ),
                          items: _products
                              .map(
                                (p) => DropdownMenuItem<Product>(
                                  value: p,
                                  child: Text(p.name),
                                ),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedProduct = val),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _quantityController,
                          decoration: const InputDecoration(
                            labelText: 'Qty',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _addItem,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(60, 50),
                        ),
                        child: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Cart List
                  Expanded(
                    child: ListView.separated(
                      itemCount: _transferItems.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (ctx, i) {
                        final item = _transferItems[i];
                        return ListTile(
                          title: Text(item['productName']),
                          trailing: Text('${item['quantity']} units'),
                          leading: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () =>
                                setState(() => _transferItems.removeAt(i)),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitTransfer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('CONFIRM TRANSFER'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
