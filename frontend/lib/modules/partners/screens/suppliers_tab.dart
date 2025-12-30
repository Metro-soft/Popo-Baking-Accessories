import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import 'package:intl/intl.dart';
import '../widgets/supplier_payment_dialog.dart';
import '../widgets/transaction_details_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/statement_pdf_service.dart';

class SuppliersTab extends StatefulWidget {
  const SuppliersTab({super.key});

  @override
  State<SuppliersTab> createState() => _SuppliersTabState();
}

class _SuppliersTabState extends State<SuppliersTab> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  List<dynamic> _suppliers = [];

  // Split View State
  Map<String, dynamic>? _selectedSupplier;
  List<dynamic> _transactions = [];
  bool _isLoadingTransactions = false;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.getSuppliers();
      setState(() => _suppliers = data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTransactions(int supplierId) async {
    setState(() => _isLoadingTransactions = true);
    try {
      final data = await _apiService.getSupplierStatement(supplierId);
      setState(() => _transactions = data['transactions'] ?? []);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading transactions: $e')));
    } finally {
      if (mounted) setState(() => _isLoadingTransactions = false);
    }
  }

  void _onSelectSupplier(Map<String, dynamic> supplier) {
    setState(() {
      _selectedSupplier = supplier;
      _transactions = []; // Clear previous
    });
    _loadTransactions(supplier['id']);
  }

  Future<void> _showSupplierDialog({Map<String, dynamic>? supplier}) async {
    final isEditing = supplier != null;
    final nameController = TextEditingController(text: supplier?['name'] ?? '');
    final contactController = TextEditingController(
      text: supplier?['contact_person'] ?? '',
    );
    final phoneController = TextEditingController(
      text: supplier?['phone'] ?? '',
    );
    final emailController = TextEditingController(
      text: supplier?['email'] ?? '',
    );
    final addressController = TextEditingController(
      text: supplier?['address'] ?? '',
    );
    final taxIdController = TextEditingController(
      text: supplier?['tax_id'] ?? '',
    );
    final openingBalanceController = TextEditingController(
      text: supplier?['opening_balance']?.toString() ?? '0',
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Supplier' : 'Add Supplier'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Company Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contactController,
                decoration: const InputDecoration(
                  labelText: 'Contact Person',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: taxIdController,
                decoration: const InputDecoration(
                  labelText: 'Tax ID (KRA PIN)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: openingBalanceController,
                decoration: const InputDecoration(
                  labelText: 'Opening Balance (Old Debt)',
                  helperText: 'Amount owed BEFORE system',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              final Map<String, dynamic> data = {
                'name': nameController.text,
                'contact_person': contactController.text,
                'phone': phoneController.text,
                'email': emailController.text,
                'address': addressController.text,
                'tax_id': taxIdController.text,
                'opening_balance':
                    double.tryParse(openingBalanceController.text) ?? 0,
              };
              navigator.pop();

              try {
                if (isEditing) {
                  await _apiService.updateSupplier(supplier['id'], data);
                } else {
                  await _apiService.createSupplier(data);
                }
                if (!mounted) return;
                _loadSuppliers();
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: Text(isEditing ? 'Save Changes' : 'Add Supplier'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSupplier(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this supplier?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _apiService.deleteSupplier(id);
        if (!mounted) return;
        _loadSuppliers();
        if (_selectedSupplier?['id'] == id) {
          setState(() => _selectedSupplier = null);
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showPaymentDialog() {
    if (_selectedSupplier == null) return;
    showDialog(
      context: context,
      builder: (context) => SupplierPaymentDialog(
        supplier: _selectedSupplier!,
        onSuccess: () {
          _loadSuppliers(); // Refresh list to update balance (if shown)
          _loadTransactions(_selectedSupplier!['id']); // Refresh history
        },
      ),
    );
  }

  void _showTransactionDetails(Map<String, dynamic> item) {
    if (item['type'] == 'payment') {
      return; // Payments don't have deep details yet, except referencing a PO maybe
    }

    showDialog(
      context: context,
      builder: (context) => TransactionDetailsDialog(
        transactionId: item['id'],
        type: 'bill',
        title: 'Purchase Order Details',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat("#,##0.00", "en_US");

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Row(
        crossAxisAlignment:
            CrossAxisAlignment.stretch, // Stretch to fill height
        children: [
          // LEFT PANEL: Supplier List
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Search suppliers...',
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 0,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: () => _showSupplierDialog(),
                              icon: const Icon(Icons.add),
                              tooltip: 'New Supplier',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.deepOrange,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _suppliers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.store,
                                  size: 64,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No suppliers yet',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _suppliers.length,
                            separatorBuilder: (ctx, i) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final supplier = _suppliers[index];
                              final isSelected =
                                  _selectedSupplier?['id'] == supplier['id'];
                              final balance =
                                  double.tryParse(
                                    supplier['current_balance']?.toString() ??
                                        '0',
                                  ) ??
                                  0;

                              return InkWell(
                                onTap: () => _onSelectSupplier(supplier),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.orange[50]
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.orange
                                          : Colors.grey[200]!,
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? []
                                        : [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.02,
                                              ),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: isSelected
                                            ? Colors.orange[100]
                                            : Colors.grey[100],
                                        child: Text(
                                          supplier['name'][0].toUpperCase(),
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.orange[900]
                                                : Colors.grey[700],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              supplier['name'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              supplier['phone'] ?? 'No Phone',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Balance Badge
                                      if (balance > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red[50],
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.red[100]!,
                                            ),
                                          ),
                                          child: Text(
                                            'KES ${NumberFormat.compact().format(balance)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red[800],
                                            ),
                                          ),
                                        ),
                                      const SizedBox(width: 4),
                                      PopupMenuButton(
                                        icon: const Icon(
                                          Icons.more_vert,
                                          color: Colors.grey,
                                        ),
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit, size: 18),
                                                SizedBox(width: 8),
                                                Text('Edit'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.delete,
                                                  color: Colors.red,
                                                  size: 18,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Delete',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _showSupplierDialog(
                                              supplier: supplier,
                                            );
                                          }
                                          if (value == 'delete') {
                                            _deleteSupplier(supplier['id']);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),

          VerticalDivider(width: 1, thickness: 1, color: Colors.grey[300]),

          // RIGHT PANEL: Transaction History
          Expanded(
            flex: 5, // More space for details
            child: Container(
              color: Colors.grey[50],
              child: _selectedSupplier == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.touch_app_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Select a supplier to view details',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : Stack(
                      children: [
                        Column(
                          children: [
                            // Header
                            Container(
                              padding: const EdgeInsets.all(24.0),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                border: Border(
                                  bottom: BorderSide(color: Colors.black12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[50],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.local_shipping_outlined,
                                      color: Colors.orange,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedSupplier!['name'],
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.confirmation_number_outlined,
                                            size: 16,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Tax ID: ${_selectedSupplier!['tax_id'] ?? 'N/A'}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Icon(
                                            Icons.person_outline,
                                            size: 16,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _selectedSupplier!['contact_person'] ??
                                                'N/A',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  // Action Buttons
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: () async {
                                          final showDetails = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => SimpleDialog(
                                              title: const Text(
                                                'Select Statement Type',
                                              ),
                                              children: [
                                                SimpleDialogOption(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        false,
                                                      ),
                                                  child: const Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          vertical: 8,
                                                        ),
                                                    child: Text(
                                                      'Summary (Total Only)',
                                                    ),
                                                  ),
                                                ),
                                                SimpleDialogOption(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        true,
                                                      ),
                                                  child: const Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          vertical: 8,
                                                        ),
                                                    child: Text(
                                                      'Detailed (With Line Items)',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (showDetails == null) return;

                                          await StatementPdfService.printStatement(
                                            party: _selectedSupplier!,
                                            transactions: _transactions,
                                            type: 'Supplier',
                                            showDetails: showDetails,
                                          );
                                        },
                                        icon: const Icon(Icons.print),
                                        tooltip: 'Print Statement',
                                      ),
                                      IconButton(
                                        onPressed: () async {
                                          final phone =
                                              _selectedSupplier!['phone']
                                                  ?.toString()
                                                  .replaceAll(
                                                    RegExp(r'[^0-9]'),
                                                    '',
                                                  ) ??
                                              '';
                                          if (phone.isEmpty) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'No phone number available',
                                                ),
                                              ),
                                            );
                                            return;
                                          }
                                          final balance =
                                              double.tryParse(
                                                _selectedSupplier!['current_balance']
                                                        ?.toString() ??
                                                    '0',
                                              ) ??
                                              0;
                                          final message = Uri.encodeComponent(
                                            'Hello ${_selectedSupplier!['name']}, find your statement attached. Outstanding Balance: KES ${format.format(balance)}.',
                                          );
                                          final url = Uri.parse(
                                            'https://wa.me/$phone?text=$message',
                                          );

                                          try {
                                            await launchUrl(
                                              url,
                                              mode: LaunchMode
                                                  .externalApplication,
                                            );
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Could not launch WhatsApp: $e',
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.share,
                                        ), // Using share icon as generic share/whatsapp
                                        tooltip: 'Share on WhatsApp',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 16),
                                  // Debt Summary
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'Outstanding Balance',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        'KES ${format.format(double.tryParse(_selectedSupplier!['current_balance']?.toString() ?? '0') ?? 0)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Statement List
                            Expanded(
                              child: _isLoadingTransactions
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : _transactions.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.receipt_long_outlined,
                                            size: 48,
                                            color: Colors.grey[300],
                                          ),
                                          const SizedBox(height: 16),
                                          const Text(
                                            'No recorded transactions',
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        16,
                                        16,
                                        80,
                                      ),
                                      itemCount: _transactions.length,
                                      itemBuilder: (context, index) {
                                        final item = _transactions[index];
                                        final isPayment =
                                            item['type'] == 'payment';
                                        final date = DateFormat(
                                          'MMM dd, yyyy',
                                        ).format(DateTime.parse(item['date']));
                                        final amount =
                                            double.tryParse(
                                              item['amount'].toString(),
                                            ) ??
                                            0;

                                        return Card(
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            side: BorderSide(
                                              color: isPayment
                                                  ? Colors.blue[100]!
                                                  : Colors.grey[200]!,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          margin: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          child: ListTile(
                                            onTap: () =>
                                                _showTransactionDetails(item),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 20,
                                                  vertical: 8,
                                                ),
                                            leading: Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: isPayment
                                                    ? Colors.green[50]
                                                    : Colors.blue[50],
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                isPayment
                                                    ? Icons.payment
                                                    : Icons
                                                          .inventory_2_outlined,
                                                color: isPayment
                                                    ? Colors.green
                                                    : Colors.blue,
                                              ),
                                            ),
                                            title: Text(
                                              isPayment
                                                  ? 'Payment Out${item['method'] != null ? ' (${item['method']})' : ''}'
                                                  : 'Purchase Bill #${item['id']}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            subtitle: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const SizedBox(height: 4),
                                                Text(
                                                  date,
                                                  style: TextStyle(
                                                    color: Colors.grey[500],
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                if (isPayment &&
                                                    item['reference'] != null)
                                                  Text(
                                                    'Ref: ${item['reference']}',
                                                    style: TextStyle(
                                                      color: Colors.grey[700],
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            trailing: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  '${isPayment ? '-' : '+'} KES ${format.format(amount)}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: isPayment
                                                        ? Colors.green[700]
                                                        : Colors.black87,
                                                  ),
                                                ),
                                                if (!isPayment)
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                          top: 4,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey[200],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: const Text(
                                                      'View Bill',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                        // Floating Action Button for Payment
                        Positioned(
                          bottom: 24,
                          right: 24,
                          child: FloatingActionButton.extended(
                            onPressed: _showPaymentDialog,
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            icon: const Icon(Icons.payment),
                            label: const Text('Record Payment'),
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
