import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../inventory/models/product_model.dart';

class ApiService {
  // Singleton Pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Use localhost:5000 as per backend env
  static const String baseUrl = 'http://localhost:5000/api';
  String? _token;

  // Auth State Notifier
  final ValueNotifier<bool> authState = ValueNotifier(false);

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
      authState.value = true;
    } else {
      throw Exception('Login Failed: ${response.body}');
    }
  }

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    authState.value = _token != null;
  }

  Future<void> logout() async {
    _token = null;
    authState.value = false;
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

  void _handleError(
    http.Response response, {
    String defaultMessage = 'Request failed',
  }) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      // Auto logout on auth error
      logout();
      throw Exception('Session expired. Please log in again.');
    }

    if (response.statusCode >= 400) {
      String message = '$defaultMessage (Status: ${response.statusCode})';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body.containsKey('error')) {
          message = body['error'];
        } else {
          message = '$message: ${response.body}';
        }
      } catch (_) {
        message = '$message: ${response.body}';
      }
      throw Exception(message);
    }
  }

  Future<List<Product>> getProducts({int? branchId}) async {
    String url = '$baseUrl/products';
    if (branchId != null) {
      url += '?branchId=$branchId';
    }
    final response = await http.get(Uri.parse(url), headers: _headers);
    _handleError(response, defaultMessage: 'Failed to load products');
    List<dynamic> body = jsonDecode(response.body);
    return body.map((dynamic item) => Product.fromJson(item)).toList();
  }

  Future<Product> getProductById(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/products/$id'),
      headers: _headers,
    );
    _handleError(response, defaultMessage: 'Failed to load product');
    return Product.fromJson(jsonDecode(response.body));
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

  Future<Product?> findProductByName(String name) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/products/check-name?name=${Uri.encodeComponent(name)}',
      ),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['found'] == true) {
        return Product.fromJson(data['product']);
      }
    }
    return null;
  }

  // Supplier & PO Methods (Keeping existing functionality)

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
    String reason, {
    int? branchId,
  }) async {
    final Map<String, dynamic> body = {
      'productId': productId,
      'quantityChange': quantity,
      'reason': reason,
    };

    if (branchId != null) {
      body['branchId'] = branchId;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/inventory/adjust'),
      headers: _headers,
      body: jsonEncode(body),
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
    return getLocations();
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

  Future<List<String>> uploadImages(List<String> filePaths) async {
    if (filePaths.isEmpty) return [];

    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));
    request.headers.addAll(_headers);

    for (var path in filePaths) {
      request.files.add(await http.MultipartFile.fromPath('images', path));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<String>.from(data['images']);
    } else {
      throw Exception('Image upload failed: ${response.body}');
    }
  }

  Future<List<String>> getCategories() async {
    final response = await http.get(
      Uri.parse('$baseUrl/categories'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      // Assuming returns [{id: 1, name: 'Flour'}, ...]. We just need names for now as product stores string.
      // Or if it returns ['Flour', 'Sugar'], handle that.
      // Safest is to handle List<dynamic> and extract 'name' if object, or toString if primitive.
      return data.map((item) {
        if (item is Map) return item['name'].toString();
        return item.toString();
      }).toList();
    } else {
      throw Exception('Failed to load categories');
    }
  }

  Future<void> createCategory(String name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/categories'),
      headers: _headers,
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to create category');
    }
  }

  Future<void> updateProduct(Product product) async {
    final response = await http.put(
      Uri.parse('$baseUrl/products/${product.id}'),
      headers: _headers,
      body: jsonEncode(product.toJson()),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update product: ${response.body}');
    }
  }

  Future<void> deleteProduct(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/products/$id'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete product: ${response.body}');
    }
  }

  Future<List<dynamic>> getStockHistory(int productId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/products/$productId/history'),
      headers: _headers,
    );
    _handleError(response, defaultMessage: 'Failed to load history');
    return jsonDecode(response.body);
  }

  Future<List<dynamic>> getStockByBranch(int productId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/inventory/product/$productId/branches'),
      headers: _headers,
    );
    _handleError(response, defaultMessage: 'Failed to load branch stock');
    return jsonDecode(response.body);
  }

  // Locations (Mother/Child)
  Future<List<dynamic>> getLocations() async {
    final response = await http.get(
      Uri.parse('$baseUrl/locations'),
      headers: _headers,
    );
    _handleError(response, defaultMessage: 'Failed to load locations');
    return jsonDecode(response.body);
  }

  Future<void> createLocation(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/locations'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (response.statusCode != 201) {
      _handleError(response, defaultMessage: 'Failed to create location');
    }
  }

  // --- Reports & Analytics ---
  Future<List<dynamic>> getAuditReport({
    int? branchId,
    String? startDate,
    String? endDate,
  }) async {
    String url = '$baseUrl/reports/audit?';
    if (branchId != null) url += 'branchId=$branchId&';
    if (startDate != null) url += 'startDate=$startDate&';
    if (endDate != null) url += 'endDate=$endDate&';

    final response = await http.get(Uri.parse(url), headers: _headers);
    _handleError(response, defaultMessage: 'Failed to generate audit report');
    return jsonDecode(response.body);
  }

  Future<List<dynamic>> getSalesPerformanceReport({
    int? branchId,
    String? startDate,
    String? endDate,
  }) async {
    String url = '$baseUrl/reports/sales?';
    if (branchId != null) url += 'branchId=$branchId&';
    if (startDate != null) url += 'startDate=$startDate&';
    if (endDate != null) url += 'endDate=$endDate&';

    final response = await http.get(Uri.parse(url), headers: _headers);
    _handleError(response, defaultMessage: 'Failed to generate sales report');
    return jsonDecode(response.body);
  }

  Future<List<dynamic>> getInventoryValuation({int? branchId}) async {
    String url = '$baseUrl/reports/valuation?';
    if (branchId != null) url += 'branchId=$branchId';

    final response = await http.get(Uri.parse(url), headers: _headers);
    _handleError(
      response,
      defaultMessage: 'Failed to generate valuation report',
    );
    return jsonDecode(response.body);
  }

  Future<List<dynamic>> getLowStockReport({int? branchId}) async {
    // Use the existing Inventory Alerts endpoint which now supports filtering
    String url = '$baseUrl/inventory/alerts?';
    if (branchId != null) url += 'branchId=$branchId';

    final response = await http.get(Uri.parse(url), headers: _headers);
    _handleError(
      response,
      defaultMessage: 'Failed to generate low stock report',
    );
    return jsonDecode(response.body);
  }

  // --- Partners (Suppliers & Customers) ---

  Future<List<dynamic>> getSuppliers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/partners/suppliers'),
      headers: _headers,
    );
    _handleError(response, defaultMessage: 'Failed to load suppliers');
    return jsonDecode(response.body);
  }

  Future<void> createSupplier(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/partners/suppliers'),
      headers: _headers,
      body: jsonEncode(data),
    );
    _handleError(response, defaultMessage: 'Failed to create supplier');
  }

  Future<void> updateSupplier(int id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/partners/suppliers/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    _handleError(response, defaultMessage: 'Failed to update supplier');
  }

  Future<void> deleteSupplier(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/partners/suppliers/$id'),
      headers: _headers,
    );
    _handleError(response, defaultMessage: 'Failed to delete supplier');
  }

  Future<List<dynamic>> getSupplierTransactions(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/partners/suppliers/$id/transactions'),
      headers: _headers,
    );
    _handleError(response, defaultMessage: 'Failed to load transactions');
    return jsonDecode(response.body);
  }

  // Customers (Using Partners API)
  Future<List<dynamic>> getCustomers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/partners/customers'),
      headers: _headers,
    );
    _handleError(response, defaultMessage: 'Failed to load customers');
    return jsonDecode(response.body);
  }

  Future<void> createCustomer(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/partners/customers'),
      headers: _headers,
      body: jsonEncode(data),
    );
    _handleError(response, defaultMessage: 'Failed to create customer');
  }

  Future<void> updateCustomer(int id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/partners/customers/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    _handleError(response, defaultMessage: 'Failed to update customer');
  }

  Future<void> deleteCustomer(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/partners/customers/$id'),
      headers: _headers,
    );
    _handleError(response, defaultMessage: 'Failed to delete customer');
  }

  Future<List<dynamic>> getCustomerTransactions(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/partners/customers/$id/transactions'),
      headers: _headers,
    );
    _handleError(response, defaultMessage: 'Failed to load transactions');
    return jsonDecode(response.body);
  }
}
