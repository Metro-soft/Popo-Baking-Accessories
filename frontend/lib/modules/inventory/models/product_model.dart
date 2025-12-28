class Product {
  final int? id;
  final String name;
  final String sku;
  final String type; // 'retail' or 'asset_rental'
  final String? description;
  final double baseSellingPrice;
  final double? rentalDeposit;
  final int reorderLevel;

  Product({
    this.id,
    required this.name,
    required this.sku,
    required this.type,
    this.description,
    required this.baseSellingPrice,
    this.rentalDeposit,
    this.reorderLevel = 10,
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
    );
  }

  // Method to convert Product instance to a map
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'sku': sku,
      'type': type,
      'description': description,
      'base_selling_price': baseSellingPrice,
      'rental_deposit_amount': rentalDeposit,
      'reorder_level': reorderLevel,
    };
  }
}
