import 'package:flutter/material.dart';
import '../providers/sales_provider.dart';
import '../../inventory/models/product_model.dart'; // Ensure Product is imported

class InvoiceTable extends StatefulWidget {
  final InvoiceDraft draft;
  final Function(int) onRemove;
  final Function(int, double) onUpdateQty;
  final Function(int, double) onUpdatePrice;
  final Function(int, String) onUpdateDesc;

  final List<Product> products;
  final Function(Product) onAdd;

  const InvoiceTable({
    super.key,
    required this.draft,
    required this.onRemove,
    required this.onUpdateQty,
    required this.onUpdatePrice,
    required this.onUpdateDesc,
    required this.products,
    required this.onAdd,
  });

  @override
  State<InvoiceTable> createState() => _InvoiceTableState();
}

class _InvoiceTableState extends State<InvoiceTable> {
  // Map to store FocusNodes for each item by ID.
  final Map<String, FocusNode> _qtyFocusNodes = {};

  @override
  void dispose() {
    for (var node in _qtyFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(InvoiceTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If an item was added
    if (widget.draft.items.length > oldWidget.draft.items.length) {
      // Focus the last item's Qty field after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Use ID based focus
        if (mounted && widget.draft.items.isNotEmpty) {
          final lastItem = widget.draft.items.last;
          _qtyFocusNodes[lastItem.id]?.requestFocus();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
          ),
          child: const Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Item / Description',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'Qty',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'Price',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'Total',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              SizedBox(width: 32), // Actions
            ],
          ),
        ),

        // Quick Entry Row (Always Visible) - styled to float
        _QuickEntryRow(products: widget.products, onAdd: widget.onAdd),

        // Body
        widget.draft.items.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(48.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 48,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Cart is Empty',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                      Text(
                        'Select items from the catalog or use search.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.draft.items.length,
                separatorBuilder: (ctx, i) =>
                    Divider(height: 1, color: Colors.grey[100]),
                itemBuilder: (ctx, index) {
                  final item = widget.draft.items[index];
                  return _InvoiceRowItem(
                    key: ValueKey(item.id),
                    item: item,
                    onRemove: () => widget.onRemove(index),
                    onUpdateQty: (val) => widget.onUpdateQty(index, val),
                    onUpdatePrice: (val) => widget.onUpdatePrice(index, val),
                    onUpdateDesc: (val) => widget.onUpdateDesc(index, val),
                  );
                },
              ),

        // Table Footer (Total Qty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
          ),
          child: Row(
            children: [
              const Expanded(flex: 3, child: SizedBox()), // Spacer for Desc
              // Total Qty
              Expanded(
                flex: 1,
                child: Text(
                  widget.draft.items
                      .fold<double>(0, (sum, item) => sum + item.quantity)
                      .toStringAsFixed(1),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const Expanded(flex: 1, child: SizedBox()), // Spacer for Price
              // Total Amount (Optional, but nice to have match)
              Expanded(
                flex: 1,
                child: Text(
                  widget.draft.items
                      .fold<double>(0, (sum, item) => sum + item.total)
                      .toStringAsFixed(2),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 48), // Spacer for Remove Icon
            ],
          ),
        ),
      ],
    );
  }
}

class _InvoiceRowItem extends StatefulWidget {
  final InvoiceItem item;
  final VoidCallback onRemove;
  final Function(double) onUpdateQty;
  final Function(double) onUpdatePrice;
  final Function(String) onUpdateDesc;

  const _InvoiceRowItem({
    super.key,
    required this.item,
    required this.onRemove,
    required this.onUpdateQty,
    required this.onUpdatePrice,
    required this.onUpdateDesc,
  });

  @override
  State<_InvoiceRowItem> createState() => _InvoiceRowItemState();
}

class _InvoiceRowItemState extends State<_InvoiceRowItem> {
  bool _isHovering = false;

  void _updateQtyRelative(int change) {
    double current = widget.item.quantity;
    double newVal = current + change;
    if (newVal < 1) newVal = 1;
    widget.onUpdateQty(newVal);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: _isHovering
            ? Colors.grey[50]
            : Colors.transparent, // Subtle highlight
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Description
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.product.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    initialValue: widget.item.description,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      hintText: 'Add description',
                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    style: const TextStyle(fontSize: 13),
                    onChanged: widget.onUpdateDesc,
                  ),
                ],
              ),
            ),

            // Qty with Hover Buttons
            Expanded(
              flex: 1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Minus Button (Visible on Hover)
                  if (_isHovering)
                    InkWell(
                      onTap: () => _updateQtyRelative(-1),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.remove,
                          size: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ),

                  // Qty Input
                  Expanded(
                    child: TextFormField(
                      key: ValueKey(
                        'qty_${widget.item.id}_${widget.item.quantity}',
                      ), // Force rebuild on external update if needed
                      initialValue: widget.item.quantity.toString(),
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (val) =>
                          widget.onUpdateQty(double.tryParse(val) ?? 0),
                    ),
                  ),

                  // Plus Button (Visible on Hover)
                  if (_isHovering)
                    InkWell(
                      onTap: () => _updateQtyRelative(1),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 14,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Unit Price
            Expanded(
              flex: 1,
              child: TextFormField(
                initialValue: widget.item.unitPrice.toString(),
                textAlign: TextAlign.right,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                ),
                onChanged: (val) =>
                    widget.onUpdatePrice(double.tryParse(val) ?? 0),
              ),
            ),

            // Total
            Expanded(
              flex: 1,
              child: Text(
                widget.item.total.toStringAsFixed(2),
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

            // Remove
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: Colors.red),
              onPressed: widget.onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickEntryRow extends StatefulWidget {
  final List<Product> products;
  final Function(Product) onAdd;

  const _QuickEntryRow({required this.products, required this.onAdd});

  @override
  State<_QuickEntryRow> createState() => _QuickEntryRowState();
}

class _QuickEntryRowState extends State<_QuickEntryRow> {
  Product? _selectedProduct;
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final FocusNode _qtyFocusNode = FocusNode();
  // We need to keep a reference to the search controller to clear it
  TextEditingController? _searchController;
  // We need to capture the focus node from the builder to refocus it
  FocusNode? _searchFocusNode;

  @override
  void dispose() {
    _qtyController.dispose();
    _qtyFocusNode.dispose();
    super.dispose();
  }

  void _handleAdd() {
    if (_selectedProduct != null) {
      final qty = double.tryParse(_qtyController.text) ?? 1;

      // LOOP approach for now to make Qty useful:
      int loopCount = qty.toInt();
      if (loopCount < 1) loopCount = 1;
      for (int i = 0; i < loopCount; i++) {
        widget.onAdd(_selectedProduct!);
      }

      // Reset
      setState(() {
        _selectedProduct = null;
        _qtyController.text = '1';
        _searchController?.clear(); // Clear search
      });

      // Refocus search for next item (Standard POS flow)
      // Note: We can only focus if we have the focus node.
      // The Autocomplete widget manages its own focus node for the text field,
      // but typically we can request focus on it if we saved it?
      // Actually, since we don't control the Autocomplete's internal focus node
      // easily from outside the builder *after* rebuilding, this is tricky.
      // Ideally, the 'autofocus' logic or just tapping it works.
      // But for "Turbo Mode", hitting Enter on Qty triggering Add should leave
      // user ready to type.
      // Since `_searchController` is just the controller, we need the focus node.
      // In `fieldViewBuilder`, we get `focusNode`. We should save it too!
      _searchFocusNode?.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Search (Autocomplete)
          Expanded(
            flex: 3,
            child: Autocomplete<Product>(
              displayStringForOption: (Product p) => p.name,
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<Product>.empty();
                }
                return widget.products.where((Product option) {
                  return option.name.toLowerCase().contains(
                        textEditingValue.text.toLowerCase(),
                      ) ||
                      option.sku.contains(textEditingValue.text);
                });
              },
              onSelected: (Product selection) {
                setState(() {
                  _selectedProduct = selection;
                });
                _qtyFocusNode.requestFocus();
              },
              fieldViewBuilder:
                  (context, textController, focusNode, onFieldSubmitted) {
                    _searchController = textController;
                    _searchFocusNode = focusNode; // Capture focus node
                    return TextField(
                      controller: textController,
                      focusNode: focusNode,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) {
                        _qtyFocusNode.requestFocus();
                      },
                      decoration: InputDecoration(
                        hintText: 'Search Item...',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 18,
                          color: Colors.grey[400],
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Colors.deepPurple,
                            width: 1,
                          ),
                        ),
                      ),
                    );
                  },
            ),
          ),
          const SizedBox(width: 12),

          // Qty - Compact (No Buttons per user request)
          Expanded(
            flex: 1,
            child: TextField(
              controller: _qtyController,
              focusNode: _qtyFocusNode,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleAdd(),
              decoration: InputDecoration(
                labelText: 'Qty',
                labelStyle: TextStyle(color: Colors.grey[400], fontSize: 11),
                floatingLabelBehavior: FloatingLabelBehavior.auto,
                filled: true,
                fillColor: Colors.grey[50],
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Colors.deepPurple,
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Price & Total (Preview)
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _selectedProduct != null
                      ? 'x ${_selectedProduct!.baseSellingPrice.toStringAsFixed(0)}'
                      : '-',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                Text(
                  _selectedProduct != null
                      ? ((double.tryParse(_qtyController.text) ?? 1) *
                                _selectedProduct!.baseSellingPrice)
                            .toStringAsFixed(2)
                      : '0.00',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Add Action
          InkWell(
            onTap: () {
              _handleAdd();
              _searchFocusNode?.requestFocus();
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.deepPurple, Colors.purpleAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.add, color: Colors.white, size: 18),
                  SizedBox(width: 4),
                  Text(
                    'ADD',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
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
