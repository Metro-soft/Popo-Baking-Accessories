class Supplier {
  final int? id;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;

  Supplier({
    this.id,
    required this.name,
    this.contactPerson,
    this.phone,
    this.email,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'],
      name: json['name'],
      contactPerson: json['contact_person'],
      phone: json['phone'],
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'contact_person': contactPerson,
      'phone': phone,
      'email': email,
    };
  }
}
