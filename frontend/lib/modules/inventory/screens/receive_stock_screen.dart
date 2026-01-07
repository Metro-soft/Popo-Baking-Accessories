import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../models/product_model.dart';
import 'package:intl/intl.dart';

class ReceiveStockScreen extends StatefulWidget {
  const ReceiveStockScreen({super.key});

  @override
  State<ReceiveStockScreen> createState() => _ReceiveStockScreenState();
}

class _ReceiveStockScreenState extends State<ReceiveStockScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  List<Map<String, dynamic>> _suppliers = [];
  List<dynamic> _branches = [];

  // List<Product> _products = []; // Removed bulk products

  // Form Fields
  int? _selectedSupplierId;
  int? _selectedBranchId;
  final TextEditingController _transportCostCtrl = TextEditingController(
    text: '0',
  );
  final TextEditingController _packagingCostCtrl = TextEditingController(
    text: '0',
  );
  final TextEditingController _invoiceRefCtrl = TextEditingController();
  DateTime? _dueDate;

  // Items Cart
  final List<Map<String, dynamic>> _cart = [];

  // Item Entry State
  Product? _currentItem;
  final TextEditingController _qtyCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final FocusNode _qtyFocusNode = FocusNode(); // [NEW] Focus Node
  DateTime? _expiryDate;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _qtyFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final s = await _apiService.getSuppliers();
      // final p = await _apiService.getProducts(); // Removed bulk fetch
      final b = await _apiService.getBranches();

      setState(() {
        _suppliers = List<Map<String, dynamic>>.from(s);
        // _products = p;
        _branches = b;
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
      _currentItem = null;
      _qtyCtrl.clear();
      _priceCtrl.clear();
      _expiryDate = null;
      // Clear the search field via the captured controller reference
      _searchController?.clear();
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
        'referenceNo': _invoiceRefCtrl.text,
        'dueDate': _dueDate?.toIso8601String(),
        'items': _cart,
      };

      await _apiService.submitStockEntry(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stock Received Successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _calculateSubtotal() {
    return _cart.fold(
      0.0,
      (sum, item) => sum + (item['quantity'] * item['unitPrice']),
    );
  }

  double _calculateTotal() {
    final sub = _calculateSubtotal();
    final transport = double.tryParse(_transportCostCtrl.text) ?? 0;
    final packaging = double.tryParse(_packagingCostCtrl.text) ?? 0;
    return sub + transport + packaging;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Receive Stock (PO)',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body:
          _isLoading &&
              _branches
                  .isEmpty // Check available data, not products
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- LEFT PANEL: List & Entry (Flex 2) ---
                  Expanded(
                    flex: 2,
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'ITEMS TO RECEIVE',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                          // Add Item Bar
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade100),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(flex: 3, child: _buildProductSearch()),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 1,
                                  child: _buildInput(
                                    _qtyCtrl,
                                    'Qty',
                                    isNumber: true,
                                    focusNode: _qtyFocusNode,
                                    onSubmitted: (_) =>
                                        _addItem(), // [NEW] Enter to Add
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: _buildInput(
                                    _priceCtrl,
                                    'Unit Cost',
                                    isNumber: true,
                                    onSubmitted: (_) =>
                                        _addItem(), // [NEW] Enter to Add
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: _addItem,
                                  icon: const Icon(Icons.add, size: 20),
                                  label: const Text('ADD'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical:
                                          12, // Match input vertical alignment
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // List
                          Expanded(
                            child: _cart.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.shopping_cart_outlined,
                                          size: 64,
                                          color: Colors.grey[200],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No items added yet',
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _cart.length,
                                    separatorBuilder: (context, index) =>
                                        const Divider(),
                                    itemBuilder: (ctx, i) {
                                      final item = _cart[i];
                                      final total =
                                          (item['quantity'] as int) *
                                          (item['unitPrice'] as double);
                                      // Calculate Landed Cost (Real Price)
                                      final double trsp =
                                          double.tryParse(
                                            _transportCostCtrl.text,
                                          ) ??
                                          0;
                                      final double pkg =
                                          double.tryParse(
                                            _packagingCostCtrl.text,
                                          ) ??
                                          0;
                                      final double totalExtra = trsp + pkg;
                                      final double totalCartValue =
                                          _calculateSubtotal(); // [FIX] Use Subtotal

                                      double realUnitCost =
                                          item['unitPrice'] as double;

                                      if (totalCartValue > 0 &&
                                          totalExtra > 0) {
                                        // Weight = ItemTotal / TotalCart
                                        final double weight =
                                            total / totalCartValue;
                                        final double allocatedExtra =
                                            totalExtra * weight;
                                        final double extraPerUnit =
                                            allocatedExtra /
                                            (item['quantity'] as int);
                                        realUnitCost += extraPerUnit;
                                      }

                                      return Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item['productName'],
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Text(
                                              '${item['quantity']} x',
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '@ ${item['unitPrice']}',
                                                  style: const TextStyle(
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                                if (realUnitCost >
                                                    (item['unitPrice']
                                                        as double))
                                                  Text(
                                                    '(Real: ${realUnitCost.toStringAsFixed(1)})',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.deepPurple,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'KES ${total.toStringAsFixed(2)}',
                                              textAlign: TextAlign.right,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.close,
                                              color: Colors.red,
                                              size: 18,
                                            ),
                                            onPressed: () => setState(
                                              () => _cart.removeAt(i),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // --- RIGHT PANEL: Summary & Logistics (Flex 1) ---
                  Expanded(
                    flex: 1,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'LOGISTICS',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[600],
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    return Autocomplete<Map<String, dynamic>>(
                                      optionsBuilder:
                                          (TextEditingValue textEditingValue) {
                                            if (textEditingValue.text.isEmpty) {
                                              return const Iterable<
                                                Map<String, dynamic>
                                              >.empty();
                                            }
                                            return _suppliers.where(
                                              (s) => s['name']
                                                  .toString()
                                                  .toLowerCase()
                                                  .contains(
                                                    textEditingValue.text
                                                        .toLowerCase(),
                                                  ),
                                            );
                                          },
                                      displayStringForOption: (option) =>
                                          option['name'],
                                      onSelected: (selection) {
                                        setState(() {
                                          _selectedSupplierId = selection['id'];
                                        });
                                      },
                                      fieldViewBuilder:
                                          (
                                            context,
                                            textEditingController,
                                            focusNode,
                                            onFieldSubmitted,
                                          ) {
                                            return TextFormField(
                                              controller: textEditingController,
                                              focusNode: focusNode,
                                              decoration: InputDecoration(
                                                labelText: 'Search Supplier',
                                                labelStyle: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 13,
                                                ),
                                                prefixIcon: const Icon(
                                                  Icons.search,
                                                  size: 20,
                                                  color: Colors.grey,
                                                ),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 10,
                                                    ),
                                                isDense: true,
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  borderSide: BorderSide(
                                                    color: Colors.grey.shade300,
                                                  ),
                                                ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      borderSide: BorderSide(
                                                        color: Colors
                                                            .grey
                                                            .shade300,
                                                      ),
                                                    ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      borderSide:
                                                          const BorderSide(
                                                            color: Colors
                                                                .deepPurple,
                                                            width: 1.5,
                                                          ),
                                                    ),
                                                filled: true,
                                                fillColor: Colors.white,
                                              ),
                                            );
                                          },
                                      optionsViewBuilder:
                                          (context, onSelected, options) {
                                            return Align(
                                              alignment: Alignment.topLeft,
                                              child: Material(
                                                elevation: 4.0,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                color: Colors.white,
                                                child: Container(
                                                  width: constraints.maxWidth,
                                                  constraints:
                                                      const BoxConstraints(
                                                        maxHeight: 250,
                                                      ),
                                                  child: ListView.separated(
                                                    padding: EdgeInsets.zero,
                                                    shrinkWrap: true,
                                                    itemCount: options.length,
                                                    separatorBuilder:
                                                        (ctx, i) =>
                                                            const Divider(
                                                              height: 1,
                                                            ),
                                                    itemBuilder:
                                                        (
                                                          BuildContext context,
                                                          int index,
                                                        ) {
                                                          final option = options
                                                              .elementAt(index);
                                                          return ListTile(
                                                            dense: true,
                                                            title: Text(
                                                              option['name'],
                                                            ),
                                                            onTap: () =>
                                                                onSelected(
                                                                  option,
                                                                ),
                                                          );
                                                        },
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                _buildDropdown(
                                  label: 'Receive To Branch',
                                  value: _selectedBranchId,
                                  items: _branches
                                      .map(
                                        (b) => DropdownMenuItem(
                                          value: b['id'],
                                          child: Text(b['name']),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => setState(
                                    () => _selectedBranchId = v as int?,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildInput(
                                  _invoiceRefCtrl,
                                  'Supplier Invoice #',
                                ),
                                const SizedBox(height: 12),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now().add(
                                        const Duration(days: 30),
                                      ),
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime(2030),
                                    );
                                    if (picked != null) {
                                      setState(() => _dueDate = picked);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.white,
                                    ),
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.calendar_today,
                                          size: 18,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _dueDate == null
                                              ? 'Due Date'
                                              : DateFormat(
                                                  'MMM d, yyyy',
                                                ).format(_dueDate!),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.normal,
                                            color: _dueDate == null
                                                ? Colors.grey[600]
                                                : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Divider(height: 48),
                                Text(
                                  'ADDITIONAL COSTS',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[600],
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildInput(
                                        _transportCostCtrl,
                                        'Transport',
                                        isNumber: true,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildInput(
                                        _packagingCostCtrl,
                                        'Packaging',
                                        isNumber: true,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 48),

                                // Totals
                                _buildSummaryRow(
                                  'Subtotal',
                                  _calculateSubtotal(),
                                ),
                                const SizedBox(height: 8),
                                _buildSummaryRow(
                                  'Transport',
                                  double.tryParse(_transportCostCtrl.text) ?? 0,
                                ),
                                const SizedBox(height: 8),
                                _buildSummaryRow(
                                  'Packaging',
                                  double.tryParse(_packagingCostCtrl.text) ?? 0,
                                ),
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'TOTAL',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'KES ${_calculateTotal().toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        color: Colors.deepPurple,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 32),
                                SizedBox(
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurple,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const CircularProgressIndicator(
                                            color: Colors.white,
                                          )
                                        : const Text(
                                            'RECEIVE STOCK',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                  ),
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
            ),
    );
  }

  Widget _buildSummaryRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        Text(
          'KES ${amount.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildInput(
    TextEditingController controller,
    String label, {
    bool isNumber = false,
    FocusNode? focusNode,
    Function(String)? onSubmitted, // [NEW] Callback
  }) {
    return TextFormField(
      controller: controller, // No SizedBox wrapper
      focusNode: focusNode,
      onFieldSubmitted: onSubmitted, // [NEW] Use it
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10, // Padding-driven height (~45-48px natural)
        ),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8), // Match POS
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.deepPurple, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildProductSearch() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Autocomplete<Product>(
          optionsBuilder: (TextEditingValue textEditingValue) async {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<Product>.empty();
            }
            // Small debounce by nature of typing speed + ApiService overhead
            // Server-side filtering via search param
            try {
              return await _apiService.getProducts(
                search: textEditingValue.text,
              );
            } catch (e) {
              debugPrint('Search error: $e');
              return const Iterable<Product>.empty();
            }
          },
          displayStringForOption: (Product option) => option.name,
          onSelected: (Product selection) {
            setState(() {
              _currentItem = selection;
              // Auto-fill price from product definition if available
              _priceCtrl.text = selection.costPrice.toString();
              // [NEW] Auto-focus Qty field
              _qtyFocusNode.requestFocus();
            });
          },
          fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
            // Hook to clear search when adding item
            if (_currentItem == null && textEditingController.text.isNotEmpty) {
              // Check if we just added an item (detected by null currentItem but text exists)
              // But this runs on build. Better to use a dedicated controller in state?
              // For Autocomplete, the internal controller is exposed here.
              // We can't force it easily from outside without a hack.
              // Instead, we'll just listen to it.
            }

            // Hack: Store controller reference to clear it later (in _addItem)
            // This is safe-ish because this builder runs synchronously in build
            // But we need a clean way.
            // A common pattern: use a key or just accept that "adding" manually clears it?
            // Autocomplete doesn't expose a controller setter easily.
            // We will use a unique Key for the Autocomplete to reset it completely?
            // Or just use the raw controller exposed here if we lift the state?
            // Simpler: Just rely on the user. But user wants efficiency.
            // Let's attach our own controller if possible? No, Autocomplete creates it.
            // Wait, we can assign the passed `textEditingController` to a field variable?
            // Yes, safe to store reference here for imperative clearing.
            _searchController = textEditingController;

            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: 'Search Product (Name/SKU)',
                labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 20,
                  color: Colors.grey,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Colors.deepPurple,
                    width: 1.5,
                  ),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
                child: Container(
                  width: constraints.maxWidth,
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 1),
                    itemBuilder: (BuildContext context, int index) {
                      final Product option = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        title: Text(
                          option.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text('SKU: ${option.sku}'),
                        trailing: Text(
                          'Stock: ${option.stockLevel.toInt()}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Helper field to hold reference to Autocomplete's controller
  TextEditingController? _searchController;

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      style: const TextStyle(
        fontSize: 14,
        color: Colors.black87,
        fontWeight: FontWeight.normal,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      icon: const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 22),
    );
  }
} // End of State class
