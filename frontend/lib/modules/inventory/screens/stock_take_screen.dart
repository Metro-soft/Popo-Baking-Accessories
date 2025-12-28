import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../models/product_model.dart';
import '../../core/screens/main_layout.dart';

class StockTakeScreen extends StatefulWidget {
  const StockTakeScreen({super.key});

  @override
  State<StockTakeScreen> createState() => _StockTakeScreenState();
}

class _StockTakeScreenState extends State<StockTakeScreen> {
  final ApiService _apiService = ApiService();
  List<Product> _products = [];
  // Map of productId -> Actual Count
  final Map<int, double> _counts = {};
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
      // Optionally fetch Low Stock alerts to merge? No, plain product list is better.
      // We might need to fetch current stock levels specifically if Product model doesn't have it up to date?
      // Product model has 'stockLevel'.
      setState(() {
        _products = products;
        // Pre-fill counts with current system stock for easier auditing (optional preference, usually blind is better)
        // Let's leave it empty (0) to force checking. Or maybe init to 0.
        for (var p in products) {
          _counts[p.id!] = 0;
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

  void _updateCount(int productId, String val) {
    if (val.isEmpty) return;
    final d = double.tryParse(val);
    if (d != null) {
      setState(() {
        _counts[productId] = d;
      });
    }
  }

  Future<void> _submitStockTake() async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirm Stock Take'),
            content: const Text(
              'This will adjust stock levels for ALL modified items. Changes cannot be undone lightly.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    setState(() => _isLoading = true);

    // We need to iterate and find variances
    // Variance = Actual - System
    // If Variance != 0, call adjustStock

    int adjustmentsMade = 0;
    List<String> errors = [];

    try {
      for (var p in _products) {
        final actual = _counts[p.id!] ?? 0;
        final system = p.stockLevel; // Assuming this is current
        final variance = actual - system;

        if (variance != 0) {
          // Send Adjustment
          String reason = 'Stock Take / Audit';
          try {
            await _apiService.adjustStock(p.id!, variance, reason);
            adjustmentsMade++;
          } catch (e) {
            errors.add('${p.name}: $e');
          }
        }
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Stock Take Completed'),
            content: Text(
              'Processed $adjustmentsMade adjustments.\nErrors: ${errors.length}',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const MainLayout()),
                  );
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Critical Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stock Take / Audit')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Banner(
                    message: 'Blind Count Mode',
                    location: BannerLocation.topStart,
                    color: Colors.orange,
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'Enter physical counts below. Variances will be auto-adjusted.',
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: _products.length,
                    separatorBuilder: (ctx, i) => const Divider(),
                    itemBuilder: (ctx, i) {
                      final p = _products[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'SKU: ${p.sku}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                  // In blind mode, maybe hide system stock?
                                  // Or show it for "Variance" check?
                                  // Let's show it for MVP transparency.
                                  Text(
                                    'System Stock: ${p.stockLevel}',
                                    style: const TextStyle(color: Colors.blue),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue: '0',
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Actual',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (val) => _updateCount(p.id!, val),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _submitStockTake,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('FINALIZE STOCK TAKE'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
