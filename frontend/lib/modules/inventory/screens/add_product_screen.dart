import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/product_model.dart';
import '../../core/services/api_service.dart';

class AddProductScreen extends StatefulWidget {
  final Product? product; // Optional: If provided, we are in "Edit Mode"
  final VoidCallback? onCancel;
  final VoidCallback? onSuccess;

  const AddProductScreen({
    super.key,
    this.product,
    this.onCancel,
    this.onSuccess,
  });

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  bool _isLoading = false;

  // Form Fields
  String _name = '';
  String _sku = '';
  String _type = 'retail';
  double _sellingPrice = 0.0;
  double? _rentalDeposit;
  int _reorderLevel = 10;

  double _costPrice = 0.0;
  String _category = 'General';
  double? _wholesalePrice;
  int _minWholesaleQty = 0;
  String? _color;
  List<String> _uploadedImageUrls = [];
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingImages = false;

  // ... (Image logic same) ...

  @override
  void initState() {
    super.initState();
    _fetchCategories();

    if (widget.product != null) {
      _loadProductData();
    } else {
      _generateSku();
    }
  }

  void _loadProductData() {
    final p = widget.product!;
    _name = p.name;
    _sku = p.sku;
    _type = p.type;
    _sellingPrice = p.baseSellingPrice;
    _rentalDeposit = p.rentalDeposit;
    _reorderLevel = p.reorderLevel;
    _costPrice = p.costPrice;
    _category = p.category;
    _wholesalePrice = p.wholesalePrice;
    _minWholesaleQty = p.minWholesaleQty;
    _color = p.color;
    _uploadedImageUrls = List.from(p.images);

    _skuController.text = _sku;

    // Defer setState for category until fetched? No, just set it.
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isEmpty) return;

    // Enforce Max 3 Limit Logic
    if (_uploadedImageUrls.length + images.length > 3) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Max 3 images allowed total')),
        );
      }
      return;
    }

    setState(() => _isUploadingImages = true);

    try {
      // Create list of paths
      List<String> paths = images.map((x) => x.path).toList();

      // Upload Immediately
      final urls = await _apiService.uploadImages(paths);

      setState(() {
        _uploadedImageUrls.addAll(urls);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload Failed: $e')));
      }
    } finally {
      setState(() => _isUploadingImages = false);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _uploadedImageUrls.removeAt(index);
    });
  }

  final TextEditingController _skuController = TextEditingController();

  List<String> _categories = ['General'];

  Future<void> _fetchCategories() async {
    try {
      final cats = await _apiService.getCategories();
      if (mounted) {
        setState(() {
          _categories = cats;
          if (_categories.isEmpty) _categories = ['General'];
          // Ensure selected category exists
          if (!_categories.contains(_category)) {
            _category = _categories.first;
          }
        });
      }
    } catch (e) {
      // Silent error or fallback
      print('Categories fetch error: $e');
    }
  }

  Future<void> _showAddCategoryDialog() async {
    String newCat = '';
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Category'),
        content: TextField(
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g. Spices',
          ),
          onChanged: (v) => newCat = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newCat.trim().isNotEmpty) {
                try {
                  // Premium Title Case Logic
                  final catName = newCat
                      .trim()
                      .split(' ')
                      .map((word) {
                        if (word.isEmpty) return '';
                        return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
                      })
                      .join(' ');

                  await _apiService.createCategory(catName);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (!mounted) return;
                  await _fetchCategories(); // Refresh
                  if (mounted) setState(() => _category = catName); // Select it
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Failed: $e')));
                  }
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _generateSku() {
    // Generate POPO-{Timestamp-Last6}{Random3}
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final random = (100 + (DateTime.now().microsecond % 900)).toString();
    // Use last 6 of timestamp + 3 random
    final shortTime = timestamp.substring(timestamp.length - 6);
    final sku = 'POPO-$shortTime$random';

    setState(() {
      _sku = sku;
      _skuController.text = sku;
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      final isEdit = widget.product != null;
      final productData = Product(
        id: isEdit ? widget.product!.id : null,
        name: _name,
        sku: _sku,
        type: _type,
        baseSellingPrice: _sellingPrice,
        rentalDeposit: _type == 'asset_rental' ? _rentalDeposit : null,
        reorderLevel: _reorderLevel,
        costPrice: _costPrice,
        category: _category,
        wholesalePrice: _wholesalePrice,
        minWholesaleQty: _minWholesaleQty,
        color: _color,
        images: _uploadedImageUrls,
      );

      if (isEdit) {
        await _apiService.updateProduct(productData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product Updated!'),
              backgroundColor: Colors.green,
            ),
          );
          if (widget.onSuccess != null) {
            widget.onSuccess!();
          } else {
            Navigator.pop(context, true);
          }
        }
      } else {
        await _apiService.createProduct(productData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product Created Successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          if (widget.onSuccess != null) {
            widget.onSuccess!();
          } else {
            _formKey.currentState!.reset();
            setState(() {
              _type = 'retail'; // Reset type
              _rentalDeposit = null;
              _uploadedImageUrls = [];
            });
            _generateSku(); // Prepare for next product
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: widget.onCancel != null
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onCancel,
              )
            : null,
        title: Text(
          widget.product != null
              ? 'Edit: ${widget.product!.name}'
              : 'Add New Product',
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive: Desktop centered card, Mobile full width
          if (constraints.maxWidth > 600) {
            return Center(
              child: SizedBox(
                width: 600,
                child: Card(
                  elevation: 4,
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: _buildForm(),
                  ),
                ),
              ),
            );
          } else {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildForm(),
            );
          }
        },
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Section
            Container(
              height: 120,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _uploadedImageUrls.isEmpty
                  ? Center(
                      child: TextButton.icon(
                        onPressed: _pickImages,
                        icon: const Icon(Icons.add_a_photo),
                        label: const Text('Add Images (Max 3)'),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(8),
                      itemCount: _uploadedImageUrls.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _uploadedImageUrls.length) {
                          // Add Button
                          return _uploadedImageUrls.length < 3
                              ? Center(
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.add_circle,
                                      size: 32,
                                      color: Color(0xFFA01B2D),
                                    ),
                                    onPressed: _pickImages,
                                  ),
                                )
                              : const SizedBox.shrink();
                        }
                        // Image Thumbnail
                        final url = _uploadedImageUrls[index];
                        // Handling local vs remote URL logic is tricky if strict.
                        // But Backend returns relative URL or full URL?
                        // Backend returns `/uploads/filename`.
                        // To show it, we need full URL.
                        // Wait, NetworkImage needs http.
                        final fullUrl =
                            '${ApiService.baseUrl.replaceAll('/api', '')}$url';

                        return Stack(
                          children: [
                            Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: NetworkImage(fullUrl),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: InkWell(
                                onTap: () => _removeImage(index),
                                child: const CircleAvatar(
                                  radius: 10,
                                  backgroundColor: Colors.red,
                                  child: Icon(
                                    Icons.close,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            if (_isUploadingImages) const LinearProgressIndicator(),
            const SizedBox(height: 16),

            // Name (Force Visible)
            Container(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextFormField(
                initialValue: _name, // Pre-fill name
                textCapitalization:
                    TextCapitalization.words, // Premium Title Case
                decoration: const InputDecoration(
                  labelText: 'Product Name',
                  hintText: 'e.g. Baking Flour 2kg',
                  prefixIcon: Icon(
                    Icons.shopping_bag,
                    color: Color(0xFFA01B2D),
                  ),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                onSaved: (v) {
                  if (v == null) return;
                  _name = v
                      .trim()
                      .split(' ')
                      .map((word) {
                        if (word.isEmpty) return '';
                        return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
                      })
                      .join(' ');
                },
              ),
            ),

            // SKU
            TextFormField(
              controller: _skuController,
              decoration: InputDecoration(
                labelText: 'SKU (Barcode)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _generateSku,
                  tooltip: 'Regenerate SKU',
                ),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              onSaved: (v) => _sku = v ?? '',
            ),
            const SizedBox(height: 16),

            // Type Dropdown (The Toggle)
            DropdownButtonFormField<String>(
              key: ValueKey(_type),
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Product Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'retail',
                  child: Text('Retail Item (Sale)'),
                ),
                DropdownMenuItem(
                  value: 'asset_rental',
                  child: Text('Rental Asset (Hire)'),
                ),
                DropdownMenuItem(
                  value: 'raw_material',
                  child: Text('Raw Material (Internal Use)'),
                ),
              ],
              onChanged: (val) {
                setState(() {
                  _type = val ?? 'retail';
                });
              },
              onSaved: (v) => _type = v ?? 'retail',
            ),
            const SizedBox(height: 16),

            // Selling & Cost Row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _sellingPrice > 0
                        ? _sellingPrice.toString()
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Base Selling Price',
                      prefixText: 'KES ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) => v == null || double.tryParse(v) == null
                        ? 'Invalid'
                        : null,
                    onSaved: (v) =>
                        _sellingPrice = double.tryParse(v ?? '0') ?? 0.0,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: _costPrice > 0 ? _costPrice.toString() : null,
                    decoration: const InputDecoration(
                      labelText: 'Cost Price',
                      prefixText: 'KES ',
                      helperText: 'For Margin Calc',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onSaved: (v) =>
                        _costPrice = double.tryParse(v ?? '0') ?? 0.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Category & Color
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(_category),
                    initialValue: _categories.contains(_category)
                        ? _category
                        : null,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.add_circle,
                          color: Color(0xFFA01B2D),
                        ),
                        onPressed: _showAddCategoryDialog,
                        tooltip: 'Add New Category',
                      ),
                    ),
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _category = v ?? 'General'),
                    onSaved: (v) => _category = v ?? 'General',
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: _color,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Color / Variant',
                      hintText: 'e.g. Red, 5kg',
                      border: OutlineInputBorder(),
                    ),
                    onSaved: (v) {
                      if (v == null || v.isEmpty) {
                        _color = null;
                        return;
                      }
                      _color = v
                          .trim()
                          .split(' ')
                          .map((word) {
                            if (word.isEmpty) return '';
                            return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
                          })
                          .join(' ');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const Text(
              'Wholesale Settings',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _wholesalePrice?.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Wholesale Price',
                      prefixText: 'KES ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onSaved: (v) =>
                        _wholesalePrice = v != null ? double.tryParse(v) : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: _minWholesaleQty > 0
                        ? _minWholesaleQty.toString()
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Min Qty',
                      helperText: 'For Wholesale',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onSaved: (v) =>
                        _minWholesaleQty = int.tryParse(v ?? '0') ?? 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),

            // Conditional Rental Deposit
            if (_type == 'asset_rental') ...[
              TextFormField(
                initialValue: _rentalDeposit?.toString(),
                decoration: const InputDecoration(
                  labelText: 'Rental Deposit Amount',
                  prefixText: 'KES ',
                  border: OutlineInputBorder(),
                  helperText: 'Refundable security deposit for this asset',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  if (_type == 'asset_rental' &&
                      (v == null || double.tryParse(v) == null)) {
                    return 'Required for Rentals';
                  }
                  return null;
                },
                onSaved: (v) => _rentalDeposit = double.tryParse(v ?? '0'),
              ),
              const SizedBox(height: 16),
            ],

            // Reorder Level
            TextFormField(
              initialValue: _reorderLevel.toString(),
              decoration: const InputDecoration(
                labelText: 'Low Stock Alert Level',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onSaved: (v) => _reorderLevel = int.tryParse(v ?? '10') ?? 10,
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        widget.product != null
                            ? 'UPDATE PRODUCT'
                            : 'SAVE PRODUCT',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
