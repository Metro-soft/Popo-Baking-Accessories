import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../models/product_model.dart';

class VariantRow {
  TextEditingController color = TextEditingController();
  TextEditingController qty = TextEditingController(text: '0');
  TextEditingController price = TextEditingController(); // Optional override
}

class BulkVariantScreen extends StatefulWidget {
  final Product templateProduct;

  const BulkVariantScreen({super.key, required this.templateProduct});

  @override
  State<BulkVariantScreen> createState() => _BulkVariantScreenState();
}

class _BulkVariantScreenState extends State<BulkVariantScreen> {
  final ApiService _apiService = ApiService();
  final List<VariantRow> _rows = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Start with 1 empty row
    _addRow();
  }

  void _addRow() {
    setState(() {
      final row = VariantRow();
      row.price.text = widget.templateProduct.baseSellingPrice.toString();
      _rows.add(row);
    });
  }

  void _removeRow(int index) {
    if (_rows.length > 1) {
      setState(() {
        _rows[index].color.dispose();
        _rows[index].qty.dispose();
        _rows[index].price.dispose();
        _rows.removeAt(index);
      });
    }
  }

  Future<void> _saveAll() async {
    setState(() => _isSaving = true);
    int successCount = 0;
    List<String> errors = [];

    try {
      for (var row in _rows) {
        if (row.color.text.trim().isEmpty) continue; // Skip empty rows

        final newProduct = widget.templateProduct.copyWith(
          id: null, // New ID will be generated
          color: row.color.text
              .trim()
              .split(' ')
              .map((word) {
                if (word.isEmpty) return '';
                return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
              })
              .join(' '),
          baseSellingPrice:
              double.tryParse(row.price.text) ??
              widget.templateProduct.baseSellingPrice,
          sku: '', // Clear SKU to allow backend to auto-generate a new one
          // We can't set initial stock here directly via Product Create usually without a separate inventory entry,
          // But for now we create the product.
          // FUTURE: Call 'receiveStock' immediately after create if Qty > 0.
        );

        // Ensure unique SKU if possible or let backend handle it
        // We rely on backend auto-gen SKU for simplicity or append color code?
        // Backend generates random SKU currently.

        try {
          final created = await _apiService.createProduct(newProduct);

          // If Qty > 0, Add Stock (Optional, but "Wizard" implies complete setup)
          final qty = double.tryParse(row.qty.text) ?? 0;
          if (qty > 0) {
            await _apiService.adjustStock(
              created.id!,
              qty,
              'Initial Bulk Setup',
            );
          }
          successCount++;
        } catch (e) {
          errors.add('${row.color.text}: $e');
        }
      }

      if (mounted) {
        if (errors.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Success! Created $successCount variants.')),
          );
          Navigator.pop(context, true); // Return success
        } else {
          _showErrorDialog(successCount, errors);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fatal Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showErrorDialog(int success, List<String> errors) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Partial Success'),
        content: SizedBox(
          height: 200,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Created $success variants successfully.'),
                const SizedBox(height: 10),
                const Text(
                  'Errors:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...errors.map(
                  (e) => Text(
                    e,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Variants: ${widget.templateProduct.name}'),
        backgroundColor: const Color(0xFFA01B2D),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                Expanded(child: _headerText('Color / Variant Name')),
                const SizedBox(width: 10),
                SizedBox(width: 80, child: _headerText('Qty')),
                const SizedBox(width: 10),
                SizedBox(width: 100, child: _headerText('Price')),
                const SizedBox(width: 40), // Delete Icon space
              ],
            ),
          ),

          // List
          Expanded(
            child: ListView.separated(
              itemCount: _rows.length,
              separatorBuilder: (c, i) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final row = _rows[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      // Color
                      Expanded(
                        child: TextField(
                          controller: row.color,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Red',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Qty
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: row.qty,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: '0',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Price
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: row.price,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            prefixText: 'KES ',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Delete
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeRow(i),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Row'),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveAll,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    _isSaving ? 'Processing...' : 'Save All Variants',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA01B2D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerText(String text) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
    );
  }
}
