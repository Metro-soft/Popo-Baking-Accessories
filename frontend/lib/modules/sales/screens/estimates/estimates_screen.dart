import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_service.dart';
import 'create_estimate_screen.dart';
import '../pos/pos_screen.dart';

class EstimatesScreen extends StatefulWidget {
  const EstimatesScreen({super.key});

  @override
  State<EstimatesScreen> createState() => _EstimatesScreenState();
}

class _EstimatesScreenState extends State<EstimatesScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _estimates = [];
  String _selectedStatus = 'pending'; // 'pending' or 'converted'
  final NumberFormat _currency = NumberFormat.currency(
    symbol: 'KES ',
    decimalDigits: 0,
  );
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _loadEstimates();
  }

  Future<void> _loadEstimates() async {
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.getEstimates(
        status: _selectedStatus == 'all' ? null : _selectedStatus,
      );
      setState(() {
        _estimates = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  Future<void> _deleteEstimate(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Estimate?'),
        content: const Text('This action cannot be undone.'),
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

    if (confirm == true) {
      try {
        await _apiService.deleteEstimate(id);
        _loadEstimates();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFA01B2D);

    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimates & Quotations',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFA01B2D),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Manage customer quotes and proposals',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateEstimateScreen(),
                      ),
                    );
                    if (result == true) {
                      _loadEstimates();
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('New Quote'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Filters
            Row(
              children: [
                _buildFilterChip('Pending', 'pending'),
                const SizedBox(width: 8),
                _buildFilterChip('Converted', 'converted'),
                const SizedBox(width: 8),
                _buildFilterChip('All', 'all'),
              ],
            ),
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _estimates.isEmpty
                  ? _buildEmptyState()
                  : _buildEstimatesList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedStatus = value;
          });
          _loadEstimates();
        }
      },
      selectedColor: const Color(0xFFA01B2D).withValues(alpha: 0.1),
      checkmarkColor: const Color(0xFFA01B2D),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFFA01B2D) : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No estimates found',
            style: TextStyle(fontSize: 18, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Future<void> _convertEstimate(int id) async {
    setState(() => _isLoading = true);
    try {
      // 1. Call API to convert (updates status + gets items)
      final result = await _apiService.convertEstimateToOrder(id);

      // 2. We need full Product objects for the POS.
      // Fetch all products (or specific ones if we had that API)
      final allProducts = await _apiService.getProducts();

      final estimateItems = result['items'] as List<dynamic>;
      final List<Map<String, dynamic>> posItems = [];

      debugPrint(
        'Convert Estimate: Fetched ${allProducts.length} products from catalog.',
      );
      debugPrint(
        'Convert Estimate: Estimate has ${estimateItems.length} items.',
      );

      for (final item in estimateItems) {
        final productId = item['productId'];
        final qty = double.tryParse(item['quantity'].toString()) ?? 1.0;
        debugPrint('Processing Item: ProductID=$productId, Qty=$qty');

        // Find matching product
        try {
          final product = allProducts.firstWhere((p) => p.id == productId);
          posItems.add({'product': product, 'quantity': qty});
          debugPrint('Match Found: ${product.name}');
        } catch (e) {
          debugPrint('Product ID $productId not found in catalog');
        }
      }

      debugPrint('Navigating to POS with ${posItems.length} items.');

      if (!mounted) return;

      // 3. Navigate to POS
      if (posItems.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quote Converted! Opening POS...')),
        );

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SalesInvoiceScreen(initialItems: posItems),
          ),
        );
        // Refresh when they return (e.g. to see status updated)
        _loadEstimates();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Converted, but no matching products found for POS.'),
          ),
        );
        _loadEstimates();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error converting: ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildEstimatesList() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListView.separated(
        itemCount: _estimates.length,
        separatorBuilder: (ctx, i) =>
            Divider(height: 1, color: Colors.grey[100]),
        itemBuilder: (ctx, i) {
          final est = _estimates[i];
          final date = DateTime.parse(est['created_at']).toLocal();
          final amount = double.tryParse(est['total_amount'].toString()) ?? 0.0;
          final status = (est['status'] ?? 'pending').toString();
          final customer = est['customer_name'] ?? 'Walk-in Customer';
          final isPending = status == 'pending';

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(status).withValues(alpha: 0.1),
              child: Icon(
                Icons.receipt_long,
                color: _getStatusColor(status),
                size: 20,
              ),
            ),
            title: Text(
              'Quote #${est['id']} - $customer',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Created: ${_dateFormat.format(date)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currency.format(amount),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 16),
                _buildStatusBadge(status),
                const SizedBox(width: 8),

                // Edit Button (Only if Pending)
                if (isPending)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CreateEstimateScreen(estimateId: est['id']),
                        ),
                      );
                      if (result == true) {
                        _loadEstimates();
                      }
                    },
                  ),

                // Convert Button (Only if Pending)
                if (isPending)
                  IconButton(
                    tooltip: 'Convert to Sale',
                    icon: const Icon(
                      Icons.shopping_cart_checkout,
                      color: Colors.green,
                    ),
                    onPressed: () => _convertEstimate(est['id']),
                  ),

                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                  onPressed: () {
                    _deleteEstimate(est['id']);
                  },
                ),
              ],
            ),
            onTap: () {
              // View Details not implemented yet
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'converted') return Colors.green;
    if (status == 'rejected') return Colors.red;
    return Colors.orange; // pending
  }
}
