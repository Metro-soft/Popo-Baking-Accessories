import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/sales_provider.dart';
import '../../widgets/invoice_table.dart';
import '../../../inventory/models/product_model.dart';
import '../../../core/services/api_service.dart';
import 'widgets/customer_selector.dart';

import '../../services/receipt_service.dart';

class SalesInvoiceScreen extends StatefulWidget {
  final VoidCallback? onExit;
  const SalesInvoiceScreen({super.key, this.onExit});

  @override
  State<SalesInvoiceScreen> createState() => _SalesInvoiceScreenState();
}

class _SalesInvoiceScreenState extends State<SalesInvoiceScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  // Future for initial load
  late Future<List<Product>> _initialLoadFuture;

  // Local state for product catalog
  List<Product> _allProducts = [];
  late TabController _productTabController;

  @override
  void initState() {
    super.initState();
    _productTabController = TabController(length: 3, vsync: this);
    // Initialize the future ONCE to prevent loops
    _initialLoadFuture = _loadData();
  }

  @override
  void dispose() {
    _productTabController.dispose();
    super.dispose();
  }

  Future<List<Product>> _loadData() async {
    try {
      debugPrint('POS: Starting Safe Load...');
      final products = await _apiService.getProducts().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Connection Timeout'),
      );
      debugPrint('POS: Loaded ${products.length} products');
      _allProducts = products; // Store locally for filtering
      return products;
    } catch (e) {
      debugPrint('POS: Load Failed: $e');
      rethrow;
    }
  }

  // --- Actions ---

  void _processPayment() {
    final sales = context.read<SalesProvider>();
    final draft = sales.activeDraft;

    if (draft.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add items to invoice first')),
      );
      return;
    }

    // [Validation] Rentals cannot be on Credit
    final rentalTotal = draft.items
        .where(
          (i) => i.product.type == 'asset_rental' || i.product.type == 'hire',
        )
        .fold(0.0, (sum, i) => sum + i.total);

    if (rentalTotal > 0) {
      if (draft.paymentMode == 'Credit') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rentals (Cake Stands) cannot be sold on Credit.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (draft.amountTendered < rentalTotal) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Insufficient Payment for Rentals. Need at least KES ${rentalTotal.toStringAsFixed(2)}',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    if (draft.paymentMode == 'Mpesa' &&
        draft.amountTendered > 0 &&
        (draft.mpesaCode == null || draft.mpesaCode!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter M-Pesa Transaction Code'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Submit
    _submitTransaction();
  }

  Future<void> _submitTransaction({bool isHold = false}) async {
    final sales = context.read<SalesProvider>();
    final draft = sales.activeDraft;

    // Build Payload
    final payload = {
      'customerId': draft.customer?['id'],
      'isHold': isHold,
      'discountAmount': draft.discountAmount,
      'discountReason': 'Manual',
      'roundOff': draft.roundOff,
      'depositChange': draft.depositChange,
      'paymentTerms': draft.paymentTerms,
      'dueDate': draft.dueDate.toIso8601String(),
      'notes': draft.notes,
      'items': draft.items
          .map(
            (item) => {
              'productId': item.product.id,
              'quantity': item.quantity,
              'unitPrice': item.unitPrice,
              'description': item.description,
              'type': item.product.type,
              'depositAmount': 0,
            },
          )
          .toList(),
      'payments': (isHold || draft.amountTendered <= 0)
          ? []
          : [
              {
                'amount': draft.amountTendered,
                'method': draft.paymentMode,
                'date': DateTime.now().toIso8601String(),
                if (draft.paymentMode == 'Mpesa') ...{
                  'referenceCode': draft.mpesaCode,
                  'phoneNumber': draft.mpesaPhone,
                },
              },
            ],
    };

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final result = await _apiService.processTransaction(payload);

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (result['success'] == false) {
        // Show Backend Error nicely
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Unknown Error'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      // Success
      if (!isHold) {
        // Print Receipt
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Printing Receipt...')));
        try {
          await ReceiptService.printReceipt(
            draft: draft,
            amountTendered: draft.amountTendered,
            change: draft.changeDue,
            cashierName: 'Admin',
          );
        } catch (e) {
          debugPrint('Print Error: $e');
        }
      }

      if (!mounted) return;
      // Success Feedback & Reset
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isHold ? 'Draft Held' : 'Transaction Complete!'),
          backgroundColor: Colors.green,
        ),
      );

      sales.closeTab(sales.activeTabIndex);
      if (sales.drafts.isEmpty) sales.addTab();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('System Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- UI Builders ---

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: _initialLoadFuture,
      builder: (context, snapshot) {
        // 1. Loading State
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initializing POS...'),
                ],
              ),
            ),
          );
        }

        // 2. Error State
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Failed to load system: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _initialLoadFuture = _loadData();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        // 3. Success State (Main UI)
        return _buildMainLayout();
      },
    );
  }

  Widget _buildMainLayout() {
    return Scaffold(
      backgroundColor: Colors.grey[100], // Premium neutral background
      appBar: AppBar(
        title: const Text(
          'Point of Sale',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black54),
          onPressed: () async {
            final nav = Navigator.of(context);
            final shouldPop = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Exit POS?'),
                content: const Text(
                  'Any unsaved changes or active drafts might be lost.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                    child: const Text('Exit'),
                  ),
                ],
              ),
            );
            if (shouldPop == true) {
              if (widget.onExit != null) {
                widget.onExit!();
              } else {
                nav.pop();
              }
            }
          },
          tooltip: 'Back to Dashboard',
        ),
        actions: [
          // Draft Management Tabs in AppBar for cleanliness
          Consumer<SalesProvider>(
            builder: (context, sales, _) {
              return SizedBox(
                width: 400,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  reverse: true, // Newest first
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: sales.drafts.length + 1,
                  separatorBuilder: (ctx, index) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    if (i == sales.drafts.length) {
                      return IconButton.filledTonal(
                        icon: const Icon(Icons.add),
                        onPressed: sales.addTab,
                        tooltip: 'New Order',
                      );
                    }
                    // final d = sales.drafts[i];
                    final isSelected = i == sales.activeTabIndex;
                    return InkWell(
                      onTap: () => sales.setActiveTab(i),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.deepPurple
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? Colors.deepPurple
                                : Colors.grey[300]!,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Order #${i + 1}',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                            if (sales.drafts.length > 1 && isSelected) ...[
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => sales.closeTab(i),
                                child: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // LEFT PANEL: Product Catalog (Flex 3)
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 8, 16),
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
                children: [
                  // Catalog Header
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.grid_view_rounded,
                          color: Colors.deepPurple,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Catalog',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        // Search Catalog
                        SizedBox(
                          width: 250,
                          height: 40,
                          child: TextField(
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search, size: 20),
                              hintText: 'Search products...',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[400],
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              contentPadding: EdgeInsets.zero,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (val) {
                              // Implement local filter if needed,
                              // or just rely on 'Quick Add' in right panel
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Categories
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: TabBar(
                      controller: _productTabController,
                      labelColor: Colors.deepPurple,
                      unselectedLabelColor: Colors.grey[600],
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'Retail Items'),
                        Tab(text: 'Rentals'),
                        Tab(text: 'Services'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Grid
                  Expanded(
                    child: TabBarView(
                      controller: _productTabController,
                      children: [
                        _buildGrid('retail'),
                        _buildGrid('asset_rental'),
                        _buildGrid('service_print'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // RIGHT PANEL: Invoice / Cart (Flex 2)
          Expanded(
            flex: 2,
            child: Consumer<SalesProvider>(
              builder: (context, sales, _) {
                final draft = sales.activeDraft;
                return Container(
                  margin: const EdgeInsets.fromLTRB(8, 16, 16, 16),
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
                    children: [
                      // Invoice Header: Customer
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.receipt_long_rounded,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Current Order',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  draft.title, // e.g. "Draft 1"
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            CustomerSelector(
                              key: ValueKey(sales.activeTabIndex),
                              initialCustomer: draft.customer,
                              onCustomerSelected: sales.setCustomer,
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),

                      // Items List
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              InvoiceTable(
                                draft: draft,
                                onRemove: sales.removeItem,
                                onUpdateQty: (i, q) =>
                                    sales.updateItem(i, quantity: q),
                                onUpdatePrice: (i, p) =>
                                    sales.updateItem(i, price: p),
                                onUpdateDesc: (i, s) =>
                                    sales.updateItem(i, description: s),
                                products: _allProducts,
                                onAdd: (p) => sales.addItem(p),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Footer (Checkout)
                      _buildFooter(draft, sales),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(String type) {
    // Filter _allProducts by type
    final filtered = _allProducts.where((p) {
      if (type == 'retail') {
        return p.type == 'retail' || p.type == 'raw_material';
      }
      return p.type == type;
    }).toList();

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, // More dense grid
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final p = filtered[i];
        return InkWell(
          onTap: () => context.read<SalesProvider>().addItem(p),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple[50], // Theme color bg
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    type == 'service_print'
                        ? Icons.print
                        : Icons.shopping_bag_outlined,
                    color: Colors.deepPurple,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    p.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'KES ${p.baseSellingPrice.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter(InvoiceDraft draft, SalesProvider sales) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Totals & Summary
          Row(
            children: [
              // Left: Payment Mode
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Method',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: draft.paymentMode,
                          isExpanded: true,
                          items: ['Cash', 'Mpesa', 'Credit']
                              .map(
                                (m) =>
                                    DropdownMenuItem(value: m, child: Text(m)),
                              )
                              .toList(),
                          onChanged: (v) => sales.setPaymentMode(v!),
                        ),
                      ),
                    ),

                    // Mpesa Details
                    if (draft.paymentMode == 'Mpesa') ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 36,
                              child: TextFormField(
                                initialValue: draft.mpesaPhone ?? '254',
                                style: const TextStyle(fontSize: 13),
                                onChanged: sales.setMpesaPhone,
                                decoration: InputDecoration(
                                  hintText: 'Phone',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 0,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  fillColor: Colors.white,
                                  filled: true,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 36,
                              child: TextFormField(
                                onChanged: sales.setMpesaCode,
                                style: const TextStyle(fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'Trans. Code',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 0,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  fillColor: Colors.white,
                                  filled: true,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),
                    const Text(
                      'Amount Received',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    PaymentAmountField(
                      amount: draft.amountTendered,
                      onChanged: sales.setAmountTendered,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Right: Financials
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _buildSummaryRow('Subtotal', draft.subtotal),
                    _buildSummaryRow(
                      'Discount (Manual)',
                      draft.discountAmount,
                      isNegative: true,
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'KES ${draft.grandTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Customer Status Bar (Debt / Wallet)
          if (draft.customer != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: draft.changeDue > 0 ? Colors.green[50] : Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: draft.changeDue > 0
                      ? Colors.green[200]!
                      : Colors.red[200]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    draft.changeDue > 0
                        ? Icons.account_balance_wallet
                        : Icons.warning_amber_rounded,
                    color: draft.changeDue > 0 ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          draft.changeDue > 0
                              ? (draft.depositChange
                                    ? 'Depositing Change to Wallet'
                                    : 'Change Due')
                              : 'Customer Debt (Projected)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: draft.changeDue > 0
                                ? Colors.green[900]
                                : Colors.red[900],
                          ),
                        ),
                        Text(
                          draft.changeDue > 0
                              ? 'KES ${draft.changeDue.toStringAsFixed(2)}'
                              : 'KES ${(double.tryParse(draft.customer!['current_debt'].toString()) ?? 0 + draft.grandTotal).toStringAsFixed(2)}', // Rough calc for display
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: draft.changeDue > 0
                                ? Colors.green[800]
                                : Colors.red[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Action Checkbox
                  if (draft.changeDue > 0)
                    Row(
                      children: [
                        Checkbox(
                          value: draft.depositChange,
                          activeColor: Colors.green,
                          onChanged: (v) =>
                              sales.toggleDepositChange(v ?? false),
                        ),
                        const Text(
                          'Deposit',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Checkbox(
                          value: draft.includeDebt,
                          activeColor: Colors.red,
                          onChanged: (v) => sales.toggleIncludeDebt(v ?? false),
                        ),
                        const Text(
                          'Pay Old Debt',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _submitTransaction(isHold: true),
                  icon: const Icon(Icons.pause, size: 18),
                  label: const Text('HOLD'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _processPayment,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    'CHARGE KES ${draft.amountTendered > 0 ? draft.amountTendered.toStringAsFixed(2) : draft.grandTotal.toStringAsFixed(2)}',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double amount, {
    bool isNegative = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(
            '${isNegative ? "-" : ""}KES ${amount.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class PaymentAmountField extends StatefulWidget {
  final double amount;
  final Function(double) onChanged;
  const PaymentAmountField({
    super.key,
    required this.amount,
    required this.onChanged,
  });

  @override
  State<PaymentAmountField> createState() => _PaymentAmountFieldState();
}

class _PaymentAmountFieldState extends State<PaymentAmountField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.amount == 0 ? '' : widget.amount.toString(),
    );
  }

  @override
  void didUpdateWidget(PaymentAmountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update text if the external change is NOT what we just typed.
    // Simple check: parse text vs new amount.
    final currentVal = double.tryParse(_controller.text) ?? 0.0;
    if ((currentVal - widget.amount).abs() > 0.01) {
      _controller.text = widget.amount == 0 ? '' : widget.amount.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: TextField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
          prefixText: 'KES ',
        ),
        onChanged: (v) => widget.onChanged(double.tryParse(v) ?? 0),
      ),
    );
  }
}

class LiveTextField extends StatefulWidget {
  final double value;
  final String? suffix;
  final String? prefix;
  final Function(double) onChanged;

  const LiveTextField({
    super.key,
    required this.value,
    required this.onChanged,
    this.suffix,
    this.prefix,
  });

  @override
  State<LiveTextField> createState() => _LiveTextFieldState();
}

class _LiveTextFieldState extends State<LiveTextField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.value));
  }

  String _format(double val) {
    if (val % 1 == 0) return val.toInt().toString();
    return val.toStringAsFixed(2);
  }

  @override
  void didUpdateWidget(LiveTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      double currentVal = double.tryParse(_controller.text) ?? 0;
      if ((currentVal - widget.value).abs() > 0.01) {
        final newValue = _format(widget.value);
        _controller.value = TextEditingValue(
          text: newValue,
          selection: TextSelection.collapsed(offset: newValue.length),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        suffixText: widget.suffix,
        prefixText: widget.prefix,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
        ),
      ),
      textAlign: TextAlign.center,
      onChanged: (v) => widget.onChanged(double.tryParse(v) ?? 0),
    );
  }
}
