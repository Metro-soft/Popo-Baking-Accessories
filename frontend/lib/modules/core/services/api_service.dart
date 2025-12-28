import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../inventory/models/product_model.dart';
import '../../procurement/models/supplier.dart';

class ApiService {
  // Singleton Pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Use localhost:5000 as per backend env
  static const String baseUrl = 'http://localhost:5000/api';
  String? _token;

  bool get isAuthenticated => _token != null;

  Future<void> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _token = data['token'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token!);
    } else {
      throw Exception('Login Failed: ${response.body}');
    }
  }

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Future<List<Product>> getProducts() async {
    final response = await http.get(
      Uri.parse('$baseUrl/products'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => Product.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load products');
    }
  }

  Future<Product> createProduct(Product product) async {
    final response = await http.post(
      Uri.parse('$baseUrl/products'),
      headers: _headers,
      body: jsonEncode(product.toJson()),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Product.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create product: ${response.body}');
    }
  }

  // Supplier & PO Methods (Keeping existing functionality)
  Future<List<dynamic>> getSuppliers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/suppliers'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load suppliers');
    }
  }

  Future<void> createSupplier(Supplier supplier) async {
    final response = await http.post(
      Uri.parse('$baseUrl/suppliers'),
      headers: _headers,
      body: jsonEncode(supplier.toJson()),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to create supplier');
    }
  }

  Future<Map<String, dynamic>> createPurchaseOrder(
    Map<String, dynamic> poData,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/purchase-orders'),
      headers: _headers,
      body: jsonEncode(poData),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create PO: ${response.body}');
    }
  }

  Future<void> receivePurchaseOrder(
    int poId,
    double transport,
    double packaging,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/purchase-orders/$poId/receive'),
      headers: _headers,
      body: jsonEncode({
        'transport_cost': transport,
        'packaging_cost': packaging,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to receive PO: ${response.body}');
    }
  }

  Future<void> submitStockEntry(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('$baseUrl/inventory/receive'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to receive stock: ${response.body}');
    }
  }

  Future<void> closeShift(int drawerId, double actualCash, String notes) async {
    final response = await http.post(
      Uri.parse('$baseUrl/security/shift/close'),
      headers: _headers,
      body: jsonEncode({
        'drawerId': drawerId,
        'actualCashAmount': actualCash,
        'notes': notes,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to close shift: ${response.body}');
    }
  }

  Future<List<dynamic>> getCustomers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/customers'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load customers');
    }
  }

  Future<void> processTransaction(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sales/transaction'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      // Pass the backend error message (e.g., Credit Limit Exceeded)
      final err = jsonDecode(response.body);
      throw Exception(err['error'] ?? 'Transaction failed');
    }
  }

  Future<Map<String, dynamic>> getDashboardStats({int? branchId}) async {
    String url = '$baseUrl/analytics/stats';
    if (branchId != null) {
      url += '?branchId=$branchId';
    }
    final response = await http.get(Uri.parse(url), headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load stats');
    }
  }

  Future<List<dynamic>> getTopProducts() async {
    final response = await http.get(
      Uri.parse('$baseUrl/analytics/top-products'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load top products');
    }
  }

  Future<List<dynamic>> getLowStockItems() async {
    final response = await http.get(
      Uri.parse('$baseUrl/inventory/alerts'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load alerts');
    }
  }

  Future<void> adjustStock(
    int productId,
    double quantity,
    String reason,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/inventory/adjust'),
      headers: _headers,
      body: jsonEncode({
        'productId': productId,
        'quantityChange': quantity,
        'reason': reason,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to adjust stock: ${response.body}');
    }
  }

  Future<void> createStockTransfer(
    int fromBranchId,
    int toBranchId,
    List<Map<String, dynamic>> items,
    String? notes,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/inventory/transfer'),
      headers: _headers,
      body: jsonEncode({
        'fromBranchId': fromBranchId,
        'toBranchId': toBranchId,
        'items': items,
        'notes': notes,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to transfer stock: ${response.body}');
    }
  }

  Future<List<dynamic>> getBranches() async {
    final response = await http.get(
      Uri.parse('$baseUrl/branches'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load branches');
    }
  }

  // --- Cash Management ---
  Future<Map<String, dynamic>> getCashStatus({int? branchId}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/cash/status?branchId=${branchId ?? 1}'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to get cash status');
    }
  }

  Future<void> openShift(int branchId, int userId, double amount) async {
    final response = await http.post(
      Uri.parse('$baseUrl/cash/open'),
      headers: _headers,
      body: json.encode({
        'branchId': branchId,
        'userId': userId,
        'openingBalance': amount,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception(
        json.decode(response.body)['error'] ?? 'Failed to open shift',
      );
    }
  }

  Future<void> closeCashShift(
    int branchId,
    double actualAmount,
    String notes,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/cash/close'),
      headers: _headers,
      body: json.encode({
        'branchId': branchId,
        'closingBalanceActual': actualAmount,
        'notes': notes,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(
        json.decode(response.body)['error'] ?? 'Failed to close shift',
      );
    }
  }

  Future<void> addCashTransaction(
    int branchId,
    int userId,
    String type,
    double amount,
    String reason,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/cash/transaction'),
      headers: _headers,
      body: json.encode({
        'branchId': branchId,
        'userId': userId,
        'type': type,
        'amount': amount,
        'reason': reason,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception(
        json.decode(response.body)['error'] ?? 'Failed to add transaction',
      );
    }
  }

  // --- Sales & Invoices ---
  Future<List<dynamic>> getSalesHistory() async {
    final response = await http.get(
      Uri.parse('$baseUrl/sales/history'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      // Return empty list if endpoint not ready yet or 404
      if (response.statusCode == 404) return [];
      throw Exception('Failed to load sales history');
    }
  }

  Future<Map<String, dynamic>> getTransactionDetails(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/sales/orders/$id'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load transaction details');
    }
  }
}
