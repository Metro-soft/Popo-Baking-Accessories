class Product {
  final int? id;
  final String name;
  final String sku;
  final String type; // 'retail' or 'asset_rental'
  final String? description;
  final double baseSellingPrice;
  final double? rentalDeposit;
  final int reorderLevel;
  final double stockLevel; // Calculated from backend

  // Enhanced Fields
  final double costPrice;
  final String category;
  final double? wholesalePrice;
  final int minWholesaleQty;
  final String? color;
  final List<String> images;

  Product({
    this.id,
    required this.name,
    required this.sku,
    required this.type,
    this.description,
    required this.baseSellingPrice,
    this.rentalDeposit,
    this.reorderLevel = 10,
    this.stockLevel = 0.0,
    this.costPrice = 0.0,
    this.category = 'General',
    this.wholesalePrice,
    this.minWholesaleQty = 0,
    this.color,
    this.images = const [],
  });

  // Factory constructor for creating a new Product instance from a map
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      sku: json['sku'],
      type: json['type'],
      description: json['description'],
      baseSellingPrice:
          double.tryParse(json['base_selling_price'].toString()) ?? 0.0,
      rentalDeposit: json['rental_deposit_amount'] != null
          ? double.tryParse(json['rental_deposit_amount'].toString())
          : null,
      reorderLevel: json['reorder_level'] ?? 10,
      stockLevel: double.tryParse(json['stock_level'].toString()) ?? 0.0,

      // Enhanced Fields Parsing
      costPrice: double.tryParse(json['cost_price']?.toString() ?? '0') ?? 0.0,
      category: json['category'] ?? 'General',
      wholesalePrice: json['wholesale_price'] != null
          ? double.tryParse(json['wholesale_price'].toString())
          : null,
      minWholesaleQty: json['min_wholesale_qty'] ?? 0,
      color: json['color'],
      images: json['images'] != null ? List<String>.from(json['images']) : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'sku': sku,
      'type': type,
      'description': description,
      'baseSellingPrice': baseSellingPrice, // Fixed: camelCase to match backend
      'rentalDeposit': rentalDeposit, // Fixed
      'reorderLevel': reorderLevel, // Fixed
      'costPrice': costPrice,
      'category': category,
      'wholesalePrice': wholesalePrice,
      'minWholesaleQty': minWholesaleQty,
      'color': color,
      'images': images,
    };
  }

  Product copyWith({
    int? id,
    String? name,
    String? sku,
    String? type,
    String? description,
    double? baseSellingPrice,
    double? rentalDeposit,
    int? reorderLevel,
    double? stockLevel,
    double? costPrice,
    String? category,
    double? wholesalePrice,
    int? minWholesaleQty,
    String? color,
    List<String>? images,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      type: type ?? this.type,
      description: description ?? this.description,
      baseSellingPrice: baseSellingPrice ?? this.baseSellingPrice,
      rentalDeposit: rentalDeposit ?? this.rentalDeposit,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      stockLevel: stockLevel ?? this.stockLevel,
      costPrice: costPrice ?? this.costPrice,
      category: category ?? this.category,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      minWholesaleQty: minWholesaleQty ?? this.minWholesaleQty,
      color: color ?? this.color,
      images: images ?? this.images,
    );
  }
}
