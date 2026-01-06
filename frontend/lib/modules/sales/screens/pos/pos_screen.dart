import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/sales_provider.dart';
import '../../widgets/invoice_table.dart';
import '../../../inventory/models/product_model.dart';
import '../../../core/services/api_service.dart';
import 'widgets/customer_selector.dart';

import '../../services/receipt_service.dart';

class SalesInvoiceScreen extends StatefulWidget {
  final VoidCallback? onExit;
  final List<Map<String, dynamic>>?
  initialItems; // { 'product': Product, 'quantity': double }

  const SalesInvoiceScreen({super.key, this.onExit, this.initialItems});

  @override
  State<SalesInvoiceScreen> createState() => _SalesInvoiceScreenState();
}

class _SalesInvoiceScreenState extends State<SalesInvoiceScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  // Future for initial load
  late Future<List<Product>> _initialLoadFuture;
  Future<List<dynamic>>? _topProductsFuture; // [MODIFIED] Nullable for safety

  // Local state for product catalog

  // Local state for product catalog
  List<Product> _allProducts = [];
  late TabController _productTabController;

  // Barcode Scanning
  String _barcodeBuffer = '';
  DateTime _lastBarcodeKeyTime = DateTime.now();

  // Search

  Timer? _debounce;

  // Controllers
  late TextEditingController _mpesaPhoneCtrl; // [NEW]

  @override
  void initState() {
    super.initState();
    _mpesaPhoneCtrl = TextEditingController(); // [NEW]
    _productTabController = TabController(length: 3, vsync: this);
    // Initialize the future ONCE to prevent loops
    _initialLoadFuture = _loadData();
    _topProductsFuture = _apiService.getTopProducts(); // [NEW] Fetch Top
    HardwareKeyboard.instance.addHandler(_onKey);

    // Handle Initial Items (e.g. from Quote Conversion)
    if (widget.initialItems != null && widget.initialItems!.isNotEmpty) {
      debugPrint(
        'POS: Processing ${widget.initialItems!.length} initial items...',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final provider = Provider.of<SalesProvider>(context, listen: false);
        provider.resetActiveDraft();
        for (final item in widget.initialItems!) {
          final product = item['product'] as Product;
          final qty = double.tryParse(item['quantity'].toString()) ?? 1.0;
          provider.addItem(product, quantity: qty);
        }
      });
    }

    // Refresh Tax Settings
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalesProvider>().refreshTaxSettings();
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _productTabController.dispose();
    _mpesaPhoneCtrl.dispose(); // [NEW]
    _debounce?.cancel();
    super.dispose();
  }

  Future<List<Product>> _loadData({String? search}) async {
    try {
      debugPrint('POS: Loading Data (Search: $search)...');
      final products = await _apiService
          .getProducts(search: search)
          .timeout(
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

  // --- Barcode Handling ---

  bool _onKey(KeyEvent event) {
    if (!mounted) return false;
    // Prevent scanning if this screen is not top-most (e.g. covered by dialog or other screen)
    if (ModalRoute.of(context)?.isCurrent != true) return false;

    if (event is KeyDownEvent) {
      final String? char = event.character;

      // Logic:
      // 1. If Enter is pressed, check buffer
      // 2. If char is printable, append to buffer if rapid
      // 3. Reset buffer if too slow

      final now = DateTime.now();
      if (now.difference(_lastBarcodeKeyTime).inMilliseconds > 100) {
        // Reset if gap is too long (manual typing)
        _barcodeBuffer = '';
      }
      _lastBarcodeKeyTime = now;

      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_barcodeBuffer.isNotEmpty) {
          _processBarcode(_barcodeBuffer);
          _barcodeBuffer = '';
          return true; // Handle enter to prevent newline in text fields? Maybe risky.
        }
      } else if (char != null &&
          char.isNotEmpty &&
          !RegExp(r'[\x00-\x1F]').hasMatch(char)) {
        _barcodeBuffer += char;
      }
    }
    return false; // Let it propagate
  }

  void _processBarcode(String code) {
    // Find product by SKU or exact name match (or barcode field if it existed)
    // Assuming SKU is the barcode for now, or match existing conventions.
    final product = _allProducts.firstWhere(
      (p) => p.sku == code || p.name == code,
      orElse: () => Product(
        id: -1,
        name: '',
        sku: '',
        type: '',
        baseSellingPrice: 0,
      ), // Dummy
    );

    if (product.id != -1) {
      context.read<SalesProvider>().addItem(product);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scanned: ${product.name}'),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      // Optional: don't annoy with errors if it was just random typing?
      // But if it was rapid + enter, it was likely a scan.
      // print('Unknown Barcode: $code');
      // Uncomment to debug:
      /*
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unknown Item: $code')),
      );
      */
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
      'taxAmount': draft.taxType == 'Inclusive'
          ? 0
          : draft.calculateTax, // Only send Tax if Exclusive (to be added)
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
      // [NEW] Dispatch Details
      'isDispatch': draft.isDispatch,
    };

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      Map<String, dynamic> result;
      if (draft.editingOrderId != null) {
        // Update Existing Sale
        result = await _apiService.updateSale(draft.editingOrderId!, payload);
      } else {
        // Create New Sale
        result = await _apiService.processTransaction(payload);
      }

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
      // Success Feedback & Reset
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isHold ? 'Draft Held' : 'Transaction Complete!'),
          backgroundColor: Colors.green,
        ),
      );

      // Auto-Clear Logic for Complete Sales
      if (!isHold) {
        final isFullPayment =
            draft.amountTendered >= (draft.totalPayable - 0.01);
        if (isFullPayment) {
          sales.resetActiveDraft();
        } else {
          // Optionally do nothing or handle partial logic
          // For now, we only auto-clear if 'Complete' as requested
        }
      } else {
        // If held, maybe we just close the tab or reset?
        // Original logic was closing tab. Let's stick to standard behavior for Hold.
        sales.closeTab(sales.activeTabIndex);
        if (sales.drafts.isEmpty) sales.addTab();
      }
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
          // Dispatch Toggle
          Consumer<SalesProvider>(
            builder: (context, sales, _) {
              final isDispatch = sales.activeDraft.isDispatch;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    Text(
                      'Dispatch',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDispatch ? Colors.orange : Colors.grey,
                      ),
                    ),
                    Switch(
                      value: isDispatch,
                      activeTrackColor: Colors.orange,
                      onChanged: (val) async {
                        sales.toggleDispatchMode(val);
                        if (val) {
                          // Show Item Selection Dialog for Delivery/Bags
                          await showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Add Dispatch Items'),
                              content: SizedBox(
                                width: double.maxFinite,
                                height: 400, // Constrain height for the list
                                child: Column(
                                  children: [
                                    const Text(
                                      'Select Delivery Service & Packaging from the list below.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Expanded(
                                      child:
                                          _allProducts.any(
                                            (p) =>
                                                p.type == 'service' ||
                                                p.name.toLowerCase().contains(
                                                  'delivery',
                                                ) ||
                                                p.name.toLowerCase().contains(
                                                  'bag',
                                                ) ||
                                                p.name.toLowerCase().contains(
                                                  'box',
                                                ),
                                          )
                                          ? ListView.separated(
                                              itemCount: _allProducts
                                                  .where(
                                                    (p) =>
                                                        p.type == 'service' ||
                                                        p.name
                                                            .toLowerCase()
                                                            .contains(
                                                              'delivery',
                                                            ) ||
                                                        p.name
                                                            .toLowerCase()
                                                            .contains('bag') ||
                                                        p.name
                                                            .toLowerCase()
                                                            .contains('box'),
                                                  )
                                                  .length,
                                              separatorBuilder:
                                                  (context, index) =>
                                                      const Divider(height: 1),
                                              itemBuilder: (context, index) {
                                                final p = _allProducts
                                                    .where(
                                                      (p) =>
                                                          p.type == 'service' ||
                                                          p.name
                                                              .toLowerCase()
                                                              .contains(
                                                                'delivery',
                                                              ) ||
                                                          p.name
                                                              .toLowerCase()
                                                              .contains(
                                                                'bag',
                                                              ) ||
                                                          p.name
                                                              .toLowerCase()
                                                              .contains('box'),
                                                    )
                                                    .toList()[index];
                                                return ListTile(
                                                  title: Text(
                                                    p.name,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  subtitle: Text(
                                                    'KES ${p.baseSellingPrice.toStringAsFixed(0)}',
                                                  ),
                                                  trailing: IconButton.filledTonal(
                                                    icon: const Icon(Icons.add),
                                                    onPressed: () {
                                                      sales.addItem(p);
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            'Added ${p.name}',
                                                          ),
                                                          duration:
                                                              const Duration(
                                                                milliseconds:
                                                                    800,
                                                              ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                );
                                              },
                                            )
                                          : const Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.inventory_2_outlined,
                                                    size: 48,
                                                    color: Colors.grey,
                                                  ),
                                                  SizedBox(height: 16),
                                                  Text(
                                                    'No Dispatch Items Found',
                                                    style: TextStyle(
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Add products with "Delivery", "Bag", or "Box" in name.',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Done'),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
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
          // LEFT PANEL: Product Catalog (Flex 2)
          Expanded(
            flex: 2,
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
                              isDense: true, // Reduced density
                            ),
                            onChanged: (val) {
                              if (_debounce?.isActive ?? false) {
                                _debounce!.cancel();
                              }
                              _debounce = Timer(
                                const Duration(milliseconds: 500),
                                () {
                                  setState(() {
                                    _initialLoadFuture = _loadData(search: val);
                                  });
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Custom Item Button
                        IconButton.filledTonal(
                          onPressed: () async {
                            final nameCtrl = TextEditingController();
                            final priceCtrl = TextEditingController();
                            final qtyCtrl = TextEditingController(text: '1');
                            final formKey = GlobalKey<FormState>();

                            await showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Add Custom Item'),
                                content: Form(
                                  key: formKey,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextFormField(
                                        controller: nameCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Item Name *',
                                        ),
                                        validator: (v) =>
                                            v!.isEmpty ? 'Required' : null,
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: priceCtrl,
                                              decoration: const InputDecoration(
                                                labelText: 'Price *',
                                              ),
                                              keyboardType:
                                                  TextInputType.number,
                                              validator: (v) => v!.isEmpty
                                                  ? 'Required'
                                                  : null,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextFormField(
                                              controller: qtyCtrl,
                                              decoration: const InputDecoration(
                                                labelText: 'Qty',
                                              ),
                                              keyboardType:
                                                  TextInputType.number,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () {
                                      if (formKey.currentState!.validate()) {
                                        final price =
                                            double.tryParse(priceCtrl.text) ??
                                            0;
                                        final qty =
                                            double.tryParse(qtyCtrl.text) ?? 1;

                                        // Add to Cart
                                        context.read<SalesProvider>().addItem(
                                          Product(
                                            id: -1, // Custom ID
                                            name: nameCtrl.text,
                                            sku: 'CUSTOM',
                                            type: 'retail', // Treat as retail
                                            baseSellingPrice: price,
                                          ),
                                          quantity: qty,
                                        );
                                        Navigator.pop(ctx);
                                      }
                                    },
                                    child: const Text('Add'),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Icons.add_shopping_cart),
                          tooltip: 'Custom Item',
                        ),
                      ],
                    ),
                  ),

                  // Quick Access (Top Selling)
                  FutureBuilder<List<dynamic>>(
                    future: _topProductsFuture ?? Future.value([]),
                    builder: (ctx, snap) {
                      if (!snap.hasData || snap.data!.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return Container(
                        height: 50,
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: snap.data!.take(8).length, // Limit to 8
                          separatorBuilder: (_, context) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final item = snap.data![i];
                            // item is {product_name, count, ...} - we might need full product?
                            // Top Products endpoint usually returns basic info.
                            // If we need full product object to add to cart, we might need to find it in _allProducts.
                            final pName =
                                (item['product_name'] ??
                                        item['name'] ??
                                        'Unknown Item')
                                    .toString();

                            return ActionChip(
                              avatar: const Icon(
                                Icons.star,
                                size: 14,
                                color: Colors.orange,
                              ),
                              label: Text(pName),
                              onPressed: () {
                                // Find in loaded products
                                try {
                                  final product = _allProducts.firstWhere(
                                    (p) => p.name == pName,
                                  );
                                  context.read<SalesProvider>().addItem(
                                    product,
                                  );
                                } catch (_) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Item details not found locally',
                                      ),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                      );
                    },
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
                  child: ClipRRect(
                    // Added ClipRRect to ensure scrolling doesn't bleed corners
                    borderRadius: BorderRadius.circular(16),
                    child: SingleChildScrollView(
                      // [MODIFIED] Scroll whole panel
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                  // [FIX] Key on draft ID so it rebuilds when draft is reset
                                  key: ValueKey(draft.id),
                                  initialCustomer: draft.customer,
                                  onCustomerSelected: sales.setCustomer,
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),

                          // Items List
                          InvoiceTable(
                            draft: draft,
                            products: _allProducts,
                            onRemove: sales.removeItem,
                            onUpdateQty: (i, q) =>
                                sales.updateItem(i, quantity: q),
                            onUpdatePrice: (i, p) =>
                                sales.updateItem(i, price: p),
                            onUpdateDesc: (i, s) =>
                                sales.updateItem(i, description: s),
                            onAdd: (p) => sales.addItem(p),
                          ),

                          // Footer
                          const Divider(height: 1),
                          _buildFooter(context, draft, sales),
                        ],
                      ),
                    ),
                  ),
                ); // Close Container
              },
            ),
          ), // Close Expanded
        ],
      ),
    );
  }

  Widget _buildGrid(String type) {
    // Filter _allProducts by TYPE only (Search is handled by Backend now)
    final filtered = _allProducts.where((p) {
      if (type == 'retail') {
        return p.type == 'retail' || p.type == 'raw_material';
      }
      return p.type == type;
    }).toList();

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // More dense grid
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

  Widget _buildFooter(
    BuildContext context,
    InvoiceDraft draft,
    SalesProvider sales,
  ) {
    // [NEW] Sync Mpesa Phone Controller
    if (draft.mpesaPhone != null && _mpesaPhoneCtrl.text != draft.mpesaPhone) {
      _mpesaPhoneCtrl.text = draft.mpesaPhone!;
    } else if (draft.mpesaPhone == null && _mpesaPhoneCtrl.text.isNotEmpty) {
      _mpesaPhoneCtrl.clear();
    }

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
          // Row 1: Main Controls
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // COL 1: Payment & Debt (Flex 3)
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Payment Method
                    const Text(
                      'Payment Method',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 38, // [MODIFIED] Compact height
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
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            size: 20,
                            color: Colors.grey,
                          ),
                          style: const TextStyle(
                            fontSize: 13, // [MODIFIED] Compact font
                            color: Colors.black87,
                          ),
                          items: ['Cash', 'Mpesa', 'Credit']
                              .map(
                                (m) =>
                                    DropdownMenuItem(value: m, child: Text(m)),
                              )
                              .toList(),
                          onChanged: (v) {
                            sales.setPaymentMode(v!);
                            if (v == 'Credit') {
                              sales.setAmountTendered(
                                0,
                              ); // Credit usually means 0 paid now
                              sales.toggleIncludeDebt(true);
                            }
                          },
                        ),
                      ),
                    ),

                    // M-Pesa Fields
                    if (draft.paymentMode == 'Mpesa') ...[
                      const SizedBox(height: 8), // Reduced spacing
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 38, // [MODIFIED] Compact height
                              child: TextFormField(
                                controller:
                                    _mpesaPhoneCtrl, // [MODIFIED] Use Ctrl
                                style: const TextStyle(fontSize: 13),
                                onChanged: sales.setMpesaPhone,
                                decoration: InputDecoration(
                                  labelText: 'Phone',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
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
                              height: 38, // [MODIFIED] Compact height
                              child: TextFormField(
                                onChanged: sales.setMpesaCode,
                                style: const TextStyle(fontSize: 13),
                                decoration: InputDecoration(
                                  labelText: 'Code',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
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

                    const SizedBox(height: 12), // Reduced spacing
                    // Amount Received Field
                    const Text(
                      'Amount Received',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 38, // [MODIFIED] Compact height
                      width: double.infinity,
                      child: LiveTextField(
                        value: draft.amountTendered,
                        prefix: 'KES ',
                        onChanged: sales.setAmountTendered,
                      ),
                    ),

                    const SizedBox(height: 16),
                    // Customer Debt / Wallet Info
                    if (draft.customer != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              (double.tryParse(
                                        draft.customer!['current_debt']
                                            .toString(),
                                      ) ??
                                      0) >
                                  0
                              ? Colors.red[50]
                              : Colors.grey[100],
                          border: Border.all(
                            color:
                                (double.tryParse(
                                          draft.customer!['current_debt']
                                              .toString(),
                                        ) ??
                                        0) >
                                    0
                                ? Colors.red[200]!
                                : Colors.grey[300]!,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Customer Debt:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'KES ${double.tryParse(draft.customer!['current_debt'].toString())?.toStringAsFixed(2) ?? "0.00"}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: Checkbox(
                                    value: draft.includeDebt,
                                    onChanged: (v) =>
                                        sales.toggleIncludeDebt(v ?? false),
                                    activeColor: Colors.red,
                                  ),
                                ),
                                const Text(
                                  ' Include in Total',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 24),

              // COL 2: Calculations (Flex 4) - Discount, Tax, Totals
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    // Subtotal
                    _buildSummaryRow('Subtotal', draft.subtotal),

                    const SizedBox(height: 8),
                    // Discount Row (Bi-directional)
                    Row(
                      children: [
                        const Expanded(
                          flex: 2,
                          child: Text(
                            'Discount',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ),
                        // Percent Input
                        Expanded(
                          flex: 2,
                          child: LiveTextField(
                            value: draft.discountRate,
                            suffix: '%',
                            onChanged: sales.setDiscountRate,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('-', style: TextStyle(color: Colors.grey)),
                        const SizedBox(width: 8),
                        // Amount Input
                        Expanded(
                          flex: 3,
                          child: LiveTextField(
                            value: draft.discountAmount,
                            prefix: 'KES ',
                            onChanged: sales
                                .setDiscountAmount, // Need to ensure provider handles calculating rate from this
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    // Tax Row
                    Row(
                      children: [
                        const Text(
                          'Tax (VAT)',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(width: 8),
                        // Type
                        SizedBox(
                          height: 30,
                          width: 80,
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: draft.taxType,
                              isDense: true,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.blue,
                              ),
                              items: ['Exclusive', 'Inclusive']
                                  .map(
                                    (t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(t),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => sales.setTaxType(v!),
                            ),
                          ),
                        ),
                        // Percent Input
                        Expanded(
                          flex: 2,
                          child: LiveTextField(
                            value: draft.taxRate,
                            suffix: '%',
                            onChanged: sales.setTaxRate,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('=', style: TextStyle(color: Colors.grey)),
                        const SizedBox(width: 8),
                        // Amount Display (Read Only)
                        Expanded(
                          flex: 3,
                          child: Container(
                            height: 36,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'KES ${draft.calculateTax.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Round Off
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: draft.roundOff,
                            onChanged: (v) => sales.toggleRoundOff(v ?? false),
                          ),
                        ),
                        const Text(
                          'Round Off',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),

                    const Divider(),
                    // Total
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
                          'KES ${draft.totalPayable.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Balance / Change
                    if (draft.amountTendered > 0 ||
                        double.tryParse(
                              draft.customer?['wallet_balance']?.toString() ??
                                  '0',
                            )! >
                            0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: draft.changeDue >= 0
                              ? Colors.green[50]
                              : Colors.red[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              draft.changeDue >= 0
                                  ? 'Change / Balance'
                                  : 'Balance Due',
                              style: TextStyle(
                                color: draft.changeDue >= 0
                                    ? Colors.green[800]
                                    : Colors.red[800],
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'KES ${draft.changeDue.abs().toStringAsFixed(2)}',
                              style: TextStyle(
                                color: draft.changeDue >= 0
                                    ? Colors.green[800]
                                    : Colors.red[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Deposit Change Option
                    if (draft.changeDue > 0 && draft.customer != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: draft.depositChange,
                              onChanged: (v) =>
                                  sales.toggleDepositChange(v ?? false),
                              activeColor: Colors.green,
                            ),
                          ),
                          const Text(
                            'Deposit to Wallet',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
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
          // Row 2: Big Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _submitTransaction(isHold: true),
                  icon: const Icon(Icons.pause, size: 20),
                  label: const Text('HOLD'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16, // [MODIFIED] Compact
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14, // [MODIFIED] Compact font
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _processPayment,
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(
                    draft.amountTendered == 0 && draft.totalPayable > 0
                        ? 'CONFIRM CREDIT SALE'
                        : (draft.amountTendered > 0 &&
                              draft.amountTendered <
                                  (draft.totalPayable - 0.01))
                        ? 'CHARGE PARTIAL (KES ${draft.amountTendered.toStringAsFixed(2)})'
                        : 'CHARGE KES ${draft.totalPayable.toStringAsFixed(2)}',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16, // [MODIFIED] Compact
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16, // [MODIFIED] Compact font
                      fontWeight: FontWeight.bold,
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
    // Only update text if the external change is NOT what we just typed (or if it's a completely new value like 0).
    // Simple check: parse text vs new amount.
    final currentVal = double.tryParse(_controller.text) ?? 0.0;
    // If the widget amount changed significantly from current text, OR if amount is 0 (reset), update text.
    if ((currentVal - widget.amount).abs() > 0.01 || widget.amount == 0) {
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
      style: const TextStyle(fontSize: 14), // [MODIFIED] Larger font
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        suffixText: widget.suffix,
        prefixText: widget.prefix,
        prefixStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        suffixStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        isDense: true,
        // [MODIFIED] Increased padding for taller fields (~44-48px)
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 10, // [MODIFIED] Compact padding
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      onChanged: (v) => widget.onChanged(double.tryParse(v) ?? 0),
    );
  }
}
