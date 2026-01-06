import 'package:flutter/material.dart';
import '../../inventory/models/product_model.dart';
import '../../core/services/settings_service.dart'; // [NEW]

class InvoiceItem {
  String id;
  Product product;
  String description;
  double quantity;
  double unitPrice;
  double discount; // Per item discount if needed, currently unused
  String? serialNumber; // For assets

  InvoiceItem({
    required this.id,
    required this.product,
    required this.description,
    this.quantity = 1,
    required this.unitPrice,
    this.discount = 0,
    this.serialNumber,
  });

  double get total => (quantity * unitPrice) - discount;
}

class InvoiceDraft {
  final String id;
  String title; // "Sale #1", "John Doe" etc.
  Map<String, dynamic>? customer;
  List<InvoiceItem> items = [];

  // Invoice Details
  DateTime date;
  DateTime dueDate;
  String paymentTerms; // "Due on Receipt", "Net 30"

  // Totals
  double discountRate = 0.0; // Percentage
  double discountAmount = 0.0; // Flat amount override or calculated

  double taxRate = 0.0; // Percentage (e.g. 16 for 16%)
  String taxType = 'Exclusive'; // 'Inclusive' or 'Exclusive'
  bool roundOff = false;

  // Payment & Debt
  bool includeDebt = false;
  String paymentMode = 'Cash'; // Cash, Mpesa, Bank, Credit
  String? mpesaCode; // For Mpesa Reference
  String? mpesaPhone = '254'; // For Mpesa Phone Number
  double amountTendered = 0.0;
  bool depositChange = false; // Deposit change to wallet

  // Dispatch Mode
  bool isDispatch = false;

  // Meta
  String notes = '';

  // Editing
  String? editingOrderId;

  InvoiceDraft({
    required this.id,
    this.title = 'New Sale',
    this.customer,
    this.editingOrderId,
    DateTime? initialDate,
    this.paymentTerms = 'Due on Receipt',
  }) : date = initialDate ?? DateTime.now(),
       dueDate = initialDate ?? DateTime.now();

  double get subtotal => items.fold(0, (sum, item) => sum + item.total);

  double get calculateDiscount => (subtotal * discountRate / 100);

  double get calculateTax {
    if (taxType == 'Inclusive') {
      // Tax is inside the subtotal (after discount assumed?)
      // Usually Tax is on the final sell price.
      // Tax = (Total / (1 + Rate)) * Rate
      double amountAfterDiscount = subtotal - calculateDiscount;
      return amountAfterDiscount -
          (amountAfterDiscount / (1 + (taxRate / 100)));
    }
    // Exclusive: Tax is on top
    return (subtotal - calculateDiscount) * taxRate / 100;
  }

  double get grandTotal {
    double total;
    if (taxType == 'Inclusive') {
      // Total is just subtotal - discount (Tax is already inside)
      total = subtotal - calculateDiscount;
    } else {
      // Total = Base + Tax
      total = subtotal - calculateDiscount + calculateTax;
    }

    if (roundOff) {
      return total.roundToDouble();
    }
    return total;
  }

  double get totalPayable {
    double total = grandTotal;
    if (includeDebt && customer != null) {
      final debt = double.tryParse(customer!['current_debt'].toString()) ?? 0.0;
      total += debt;
    }
    return total;
  }

  double get changeDue {
    return amountTendered - totalPayable;
  }

  void updateDueDate() {
    // Simple logic for now
    if (paymentTerms == 'Net 15') {
      dueDate = date.add(const Duration(days: 15));
    } else if (paymentTerms == 'Net 30') {
      dueDate = date.add(const Duration(days: 30));
    } else {
      dueDate = date;
    }
  }
}

class SalesProvider extends ChangeNotifier {
  final List<InvoiceDraft> _drafts = [];
  final SettingsService _settingsService = SettingsService(); // [NEW]
  int _activeTabIndex = 0;

  // Global Defaults
  double _globalTaxRate = 0.0;
  String _globalTaxType = 'Exclusive';

  SalesProvider() {
    refreshTaxSettings(); // [NEW]
    _addNewDraft(); // Start with one tab
  }

  Future<void> refreshTaxSettings() async {
    try {
      final settings = await _settingsService.fetchSettings();
      _globalTaxRate = double.tryParse(settings['tax_rate'] ?? '0') ?? 0.0;
      _globalTaxType = settings['default_tax_type'] ?? 'Exclusive';

      // Update the initial draft if it's empty/untouched?
      // Or just ensure future drafts usage.
      // Let's update all current drafts if they are "fresh" (no items)?
      // For now, just setting globals for future reference is enough,
      // but to make it feel immediate, we might update the active draft if it has 0 items.
      if (_drafts.isNotEmpty && _drafts.first.items.isEmpty) {
        _drafts.first.taxRate = _globalTaxRate;
        _drafts.first.taxType = _globalTaxType;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading sales globals: $e');
    }
  }

  List<InvoiceDraft> get drafts => _drafts;
  int get activeTabIndex => _activeTabIndex;
  InvoiceDraft get activeDraft => _drafts[_activeTabIndex];

  void _addNewDraft() {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    _drafts.add(
      InvoiceDraft(id: newId, title: 'Sale #${_drafts.length + 1}')
        ..taxRate =
            _globalTaxRate // [NEW]
        ..taxType = _globalTaxType, // [NEW]
    );
    // Switch to new tab if it's not the first initialization (optional)
    if (_drafts.length > 1) {
      _activeTabIndex = _drafts.length - 1;
    }
    notifyListeners();
  }

  void addTab() {
    _addNewDraft();
  }

  void closeTab(int index) {
    if (_drafts.length <= 1) return; // Don't close last tab
    _drafts.removeAt(index);

    // Adjust active index
    if (_activeTabIndex >= index && _activeTabIndex > 0) {
      _activeTabIndex--;
    }
    notifyListeners();
  }

  void setActiveTab(int index) {
    _activeTabIndex = index;
    notifyListeners();
  }

  // --- Invoice Actions for Active Draft ---

  void setCustomer(Map<String, dynamic>? customer) {
    activeDraft.customer = customer;
    // Auto-update title?
    if (customer != null) {
      activeDraft.title = customer['name'];
      // [NEW] Auto-fill Mpesa Phone
      if (customer['phone'] != null) {
        activeDraft.mpesaPhone = customer['phone'].toString();
      }
    }
    notifyListeners();
  }

  // [NEW] Set Editing Mode
  void setEditingSale(String id) {
    activeDraft.editingOrderId = id;
    activeDraft.title = 'Edit Sale #$id';
    notifyListeners();
  }

  void addItem(Product product, {String type = 'retail', double quantity = 1}) {
    // Check if exists? For Professional Invoice, maybe we just add new row?
    // Let's deduce: usually we want to group items.

    final existingIndex = activeDraft.items.indexWhere(
      (i) =>
          i.product.id == product.id && i.unitPrice == product.baseSellingPrice,
    );

    if (existingIndex != -1) {
      // Update qty
      activeDraft.items[existingIndex].quantity += quantity;
    } else {
      activeDraft.items.add(
        InvoiceItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          product: product,
          description: product.name, // Editable
          quantity: quantity,
          unitPrice: product.baseSellingPrice,
        ),
      );
    }
    notifyListeners();
  }

  void updateItem(
    int index, {
    double? quantity,
    double? price,
    String? description,
  }) {
    if (index < 0 || index >= activeDraft.items.length) return;

    if (quantity != null) activeDraft.items[index].quantity = quantity;
    if (price != null) activeDraft.items[index].unitPrice = price;
    if (description != null) activeDraft.items[index].description = description;

    notifyListeners();
  }

  void removeItem(int index) {
    if (index < 0 || index >= activeDraft.items.length) return;
    activeDraft.items.removeAt(index);
    notifyListeners();
  }

  void setDiscountAmount(double amount) {
    if (activeDraft.subtotal <= 0) return;
    activeDraft.discountRate = (amount / activeDraft.subtotal) * 100;
    notifyListeners();
  }

  void setDiscountRate(double rate) {
    activeDraft.discountRate = rate;
    notifyListeners();
  }

  void setTaxRate(double rate) {
    activeDraft.taxRate = rate;
    notifyListeners();
  }

  void toggleRoundOff(bool value) {
    activeDraft.roundOff = value;
    notifyListeners();
  }

  void toggleIncludeDebt(bool value) {
    activeDraft.includeDebt = value;
    notifyListeners();
  }

  void setPaymentMode(String mode) {
    activeDraft.paymentMode = mode;
    notifyListeners();
  }

  void setAmountTendered(double amount) {
    activeDraft.amountTendered = amount;
    notifyListeners();
  }

  void setMpesaCode(String code) {
    activeDraft.mpesaCode = code;
    notifyListeners();
  }

  void setMpesaPhone(String phone) {
    activeDraft.mpesaPhone = phone;
    notifyListeners();
  }

  void toggleDepositChange(bool value) {
    activeDraft.depositChange = value;
    notifyListeners();
  }

  // --- Dispatch Actions ---

  void toggleDispatchMode(bool value) {
    activeDraft.isDispatch = value;
    notifyListeners();
  }

  void setTaxType(String type) {
    activeDraft.taxType = type;
    notifyListeners();
  }

  void setPaymentTerms(String term) {
    activeDraft.paymentTerms = term;
    activeDraft.updateDueDate();
    notifyListeners();
  }

  void resetActiveDraft() {
    // Replace with a fresh draft but keep ID or generate new?
    // Usually easier to just replace the object content or the object itself
    _drafts[_activeTabIndex] =
        InvoiceDraft(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: 'New Sale', // Reset title
          )
          ..taxRate =
              _globalTaxRate // [NEW]
          ..taxType = _globalTaxType; // [NEW]
    notifyListeners();
  }
}
