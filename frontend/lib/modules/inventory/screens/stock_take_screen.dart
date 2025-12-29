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
  List<dynamic> _branches = [];
  int? _selectedBranchId;
  // Map of productId -> Actual Count
  final Map<int, double> _counts = {};

  // Advanced Audit State
  final Map<int, int> _attempts = {}; // ProductId -> Attempt Count
  final Map<int, bool> _locked = {}; // ProductId -> Is Locked?
  final Map<int, bool> _verified = {}; // ProductId -> Is Verified?

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      // 1. Load Branches if empty
      if (_branches.isEmpty) {
        final branches = await _apiService.getBranches();
        if (mounted) {
          setState(() {
            _branches = branches;
            if (_branches.isNotEmpty && _selectedBranchId == null) {
              _selectedBranchId = _branches[0]['id'];
            }
          });
        }
      }

      // 2. Load Products specific to the selected branch
      final products = await _apiService.getProducts(
        branchId: _selectedBranchId,
      );

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
    if (_locked[productId] == true) return; // Prevent editing if locked

    if (val.isEmpty) return;
    final d = double.tryParse(val);
    if (d != null) {
      setState(() {
        _counts[productId] = d;
      });
    }
  }

  // Phase 1: Verification Logic (The 3-Strike Rule)
  void _verifyCounts() {
    setState(() {
      int mismatches = 0;

      for (var p in _products) {
        // Skip if already verified or locked
        if (_verified[p.id] == true || _locked[p.id] == true) continue;

        final actual = _counts[p.id] ?? 0;
        final system = p.stockLevel;

        if (actual == system) {
          _verified[p.id!] = true;
        } else {
          // Mismatch Found
          mismatches++;
          int currentAttempts = _attempts[p.id!] ?? 0;
          currentAttempts++;

          if (currentAttempts >= 3) {
            // STRIKE 3: Lock it
            _locked[p.id!] = true;
            _attempts[p.id!] = currentAttempts;
          } else {
            // Strike 1 or 2: Just increment
            _attempts[p.id!] = currentAttempts;
          }
        }
      }

      if (mismatches > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mismatches found. Please recount yellow items.'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        // All clear!
        _showFinalReport();
      }
    });
  }

  Future<void> _showFinalReport() async {
    // Calculate final stats
    int verifiedCount = _verified.values.where((v) => v).length;
    int escalatedCount = _locked.values.where((v) => v).length;

    bool confirm =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Audit Report'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verified Matches: $verifiedCount',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Escalated / Locked: $escalatedCount',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Submit these results to Head Office?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Submit Report'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    setState(() => _isLoading = true);

    int adjustmentsMade = 0;
    List<String> errors = [];

    try {
      for (var p in _products) {
        final actual = _counts[p.id!] ?? 0;
        final system = p.stockLevel;
        final variance = actual - system;

        // If variance is 0, we still might want to log 'Verified' audit event,
        // but adjustStock usually expects a change.
        // For now, only send items with Variance != 0 (Escalated or Accepted).
        if (variance == 0) continue;

        String reason = _locked[p.id] == true
            ? 'Audit: Escalated Discrepancy (Attempt 3 Failed)'
            : 'Audit: Manual Adjustment';

        try {
          await _apiService.adjustStock(
            p.id!,
            variance,
            reason,
            branchId: _selectedBranchId,
          );
          adjustmentsMade++;
        } catch (e) {
          errors.add('${p.name}: $e');
        }
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Audit Completed'),
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
                child: const Text('Finish'),
              ),
            ],
          ),
        );
      }
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
                // Branch Selector
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedBranchId,
                    decoration: const InputDecoration(
                      labelText: 'Select Branch to Count',
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
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedBranchId = val;
                          _isLoading = true; // Trigger reload
                        });
                        _loadProducts();
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: _products.length,
                    separatorBuilder: (ctx, i) => const Divider(),
                    itemBuilder: (ctx, i) {
                      final p = _products[i];

                      // Determine Row State
                      bool isLocked = _locked[p.id] == true;
                      bool isVerified = _verified[p.id] == true;
                      int attempts = _attempts[p.id] ?? 0;

                      Color? rowColor;
                      if (isLocked) {
                        rowColor = Colors.red.shade50;
                      } else if (isVerified) {
                        rowColor = Colors.green.shade50;
                      } else if (attempts > 0) {
                        rowColor = Colors.orange.shade50;
                      }

                      return Container(
                        color: rowColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: Row(
                          children: [
                            // Status Icon
                            if (isLocked)
                              const Icon(Icons.lock, color: Colors.red),
                            if (isVerified)
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                            if (attempts > 0 && !isLocked && !isVerified)
                              const Icon(Icons.warning, color: Colors.orange),
                            const SizedBox(width: 8),

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

                                  // HIDE SYSTEM STOCK IN BLIND MODE
                                  // Text('System Stock: ${p.stockLevel}', style: const TextStyle(color: Colors.blue)),
                                  if (isLocked)
                                    Text(
                                      'Failed 3 Attempts. Escalated.',
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  if (attempts > 0 && !isLocked && !isVerified)
                                    Text(
                                      '$attempts/3 Attempts Failed',
                                      style: TextStyle(
                                        color: Colors.orange.shade800,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue: '0',
                                enabled:
                                    !isLocked &&
                                    !isVerified, // Disable if locked/verified
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Actual',
                                  border: const OutlineInputBorder(),
                                  fillColor: Colors.white,
                                  filled: true,
                                  suffixIcon: isLocked
                                      ? const Icon(Icons.lock_outline, size: 16)
                                      : null,
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
                      onPressed: _verifyCounts,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('VERIFY COUNTS'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
