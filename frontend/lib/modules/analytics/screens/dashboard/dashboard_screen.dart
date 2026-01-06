import 'package:flutter/material.dart';
import '../../../../modules/core/services/api_service.dart'; // Correct path from analytics/screens/dashboard/ -> core/services/

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;

  Map<String, dynamic>? _stats;
  List<dynamic> _topProducts = [];
  List<dynamic> _lowStockItems = [];

  List<dynamic> _branches = [];
  int? _selectedBranchId;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final branches = await _apiService.getBranches();
      if (mounted) {
        setState(() {
          _branches = branches;
        });
      }
      await _loadStats();
    } catch (e) {
      debugPrint('Error loading branches: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStats() async {
    // Note: Do not override _isLoading here to avoid flicker if just refreshing stats
    try {
      final stats = await _apiService.getDashboardStats(
        branchId: _selectedBranchId,
      );
      final products = await _apiService.getTopProducts();
      final lowStock = await _apiService.getLowStockItems();

      if (mounted) {
        setState(() {
          _stats = stats;
          _topProducts = products;
          _lowStockItems = lowStock;
        });
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  void _onBranchChanged(int? branchId) {
    setState(() {
      _selectedBranchId = branchId;
      _isLoading = true;
    });
    _loadStats().whenComplete(() {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          _buildSalesOverview(),
          const SizedBox(height: 32),
          if (_lowStockItems.isNotEmpty) ...[
            _buildLowStockAlerts(),
            const SizedBox(height: 32),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildOrdersOverview()),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: _buildTopProducts()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockAlerts() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.red[700],
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Low Stock Alerts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: _lowStockItems.map((item) {
              return Chip(
                avatar: const Icon(
                  Icons.inventory_2,
                  size: 16,
                  color: Colors.white,
                ),
                label: Text(
                  '${item['name']} (${item['total_quantity']} left)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                backgroundColor: Colors.red[400],
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Welcome, Admin 👋',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Here's what's happening in your store.",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
        Row(
          children: [
            // Branch Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedBranchId,
                  hint: const Text('All Branches'),
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text(
                        'All Branches',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ..._branches.map(
                      (b) => DropdownMenuItem<int>(
                        value: b['id'],
                        child: Text(b['name']),
                      ),
                    ),
                  ],
                  onChanged: _onBranchChanged,
                ),
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              onPressed: () => _onBranchChanged(_selectedBranchId),
              icon: const Icon(Icons.refresh),
              iconSize: 28,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSalesOverview() {
    final revenue = _stats?['totalRevenue'] ?? 0;
    final orders = _stats?['totalOrders'] ?? 0;
    final customers = _stats?['totalCustomers'] ?? 0;
    final expenses = _stats?['totalExpenses'] ?? 0;
    final pendingBills = _stats?['totalPendingBills'] ?? 0;
    final monthlyPurchases = _stats?['monthlyPurchases'] ?? 0;
    final purchasesPayable = _stats?['purchasesPayable'] ?? 0;
    final receivables = _stats?['totalReceivables'] ?? 0;

    return Column(
      children: [
        // Row 1: Key Metrics
        Row(
          children: [
            Expanded(
              child: _buildSplitSummaryCard(
                title: 'Revenue Overview',
                label1: 'Total Revenue',
                value1: 'KES ${revenue.toStringAsFixed(0)}',
                label2: 'You will Receive',
                value2: 'KES ${receivables.toStringAsFixed(0)}',
                iconColor: Colors.orange,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildSummaryCard(
                title: 'Total Orders',
                value: orders.toString(),
                change: '+5.2%',
                color: const Color(0xFFF3E8FF),
                iconColor: Colors.purple,
                icon: Icons.shopping_bag_outlined,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildSummaryCard(
                title: 'Total Customers',
                value: customers.toString(),
                change: '+2.1%',
                color: const Color(0xFFE0F7FA),
                iconColor: Colors.cyan,
                icon: Icons.people_outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Row 2: Financial Obligations
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'Monthly Expenses',
                value: 'KES ${expenses.toStringAsFixed(0)}',
                change: 'High',
                color: Colors.pink[50]!,
                iconColor: Colors.pink,
                icon: Icons.receipt_long,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildSummaryCard(
                title: 'Pending Bills',
                value: 'KES ${pendingBills.toStringAsFixed(0)}',
                change: 'Due Soon',
                color: Colors.red[50]!,
                iconColor: Colors.red,
                icon: Icons.warning_amber_rounded,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildSplitSummaryCard(
                title: 'Purchases',
                label1: 'Monthly Purchase',
                value1: 'KES ${monthlyPurchases.toStringAsFixed(0)}',
                label2: 'You will Give',
                value2: 'KES ${purchasesPayable.toStringAsFixed(0)}',
                iconColor: Colors.blue[800],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSplitSummaryCard({
    required String title,
    required String label1,
    required String value1,
    required String label2,
    required String value2,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.blue[50], // Light blue for Purchases
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shopping_cart,
                  color: iconColor ?? Colors.blue,
                  size: 28,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value1,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label1,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: Colors.grey[300]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value2,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label2,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String change,
    required Color color,
    required Color iconColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildOrdersOverview() {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Orders Overview',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Spacer(),
          const Center(
            child: Text(
              'Chart Implementation Pending\n(Requires fl_chart)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildTopProducts() {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Products',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _topProducts.isEmpty
                ? const Center(child: Text('No Sales Yet'))
                : ListView.builder(
                    itemCount: _topProducts.length,
                    itemBuilder: (ctx, i) {
                      final p = _topProducts[i];
                      return _buildProductItem(
                        (p['product_name'] ?? p['name'] ?? 'Unknown')
                            .toString(),
                        p['sku'] ?? '',
                        p['total_sold'].toString(),
                        Colors.deepPurple,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(String name, String sku, String count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.inventory_2_outlined, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  sku,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '$count Sold',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
