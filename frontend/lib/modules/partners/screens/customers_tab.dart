import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_service.dart';
import '../widgets/customer_form_panel.dart';
import '../widgets/transaction_details_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/services/statement_pdf_service.dart';
import '../../core/services/settings_service.dart';
import '../widgets/reminder_card.dart';

class CustomersTab extends StatefulWidget {
  const CustomersTab({super.key});

  @override
  State<CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<CustomersTab> {
  final ApiService _apiService = ApiService();
  final SettingsService _settingsService = SettingsService(); // New
  final ScreenshotController _screenshotController =
      ScreenshotController(); // New
  bool _isLoading = false;
  List<dynamic> _customers = [];

  // Split View State
  Map<String, dynamic>? _selectedCustomer;
  List<dynamic> _transactions = [];
  bool _isLoadingTransactions = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.getCustomers();
      setState(() => _customers = data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTransactions(int customerId) async {
    setState(() => _isLoadingTransactions = true);
    try {
      final data = await _apiService.getCustomerStatement(customerId);
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

  bool _isEditing = false; // New State for Panel Mode

  void _onSelectCustomer(Map<String, dynamic> customer) {
    setState(() {
      _selectedCustomer = customer;
      _isEditing = false; // Switch to view mode
      _transactions = []; // Clear previous
    });
    _loadTransactions(customer['id']);
  }

  void _startCreating() {
    setState(() {
      _selectedCustomer = null;
      _isEditing = true;
    });
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
  }

  void _cancelForm() {
    setState(() {
      // If we were creating, go back to nothing. If editing, go back to details.
      if (_selectedCustomer == null) {
        _isEditing = false;
      } else {
        _isEditing = false;
      }
    });
  }

  Future<void> _handleFormSave(Map<String, dynamic> data) async {
    final isUpdate = _selectedCustomer != null;

    // Optimistic / Loading state if needed

    try {
      if (isUpdate) {
        await _apiService.updateCustomer(_selectedCustomer!['id'], data);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customer updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        await _apiService.createCustomer(data);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customer created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Refresh
      await _loadCustomers();

      // Update Selection
      if (isUpdate) {
        final updated = _customers.firstWhere(
          (c) => c['id'] == _selectedCustomer!['id'],
          orElse: () => null,
        );
        if (updated != null) {
          setState(() {
            _selectedCustomer = updated;
            _isEditing = false;
          });
        }
      } else {
        // If created, maybe select the new one? For now just go to list
        setState(() {
          _isEditing = false;
          // Ideally find the new customer and select it, but we can leave it unselected for now
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteCustomer(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text(
          'Are you sure you want to delete this customer? This might fail if they have linked transactions.',
        ),
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
        await _apiService.deleteCustomer(id);
        if (!mounted) return;
        _loadCustomers();
        if (_selectedCustomer?['id'] == id) {
          setState(() => _selectedCustomer = null);
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showPaymentDialog() async {
    if (_selectedCustomer == null) return;
    final customerId = _selectedCustomer!['id'];

    // Load un-paid orders first
    debugPrint('Opening Payment Dialog for Customer: $customerId');
    List<dynamic> unpaidOrders = [];
    try {
      unpaidOrders = await _apiService.getCustomerUnpaidOrders(customerId);
    } catch (e) {
      // Ignore or show warning, still allow generic payment
      print('Failed to load unpaid orders: $e');
    }

    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String method = 'M-Pesa'; // Default
    int? selectedOrderId;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (sbContext, setDialogState) {
          return AlertDialog(
            title: const Text('Receive Payment'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    key: ValueKey(selectedOrderId),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Link to Order (Optional)',
                      border: OutlineInputBorder(),
                      helperText: 'Select an order to pay off specific debt',
                    ),
                    initialValue: selectedOrderId,
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('None (General Payment)'),
                      ),
                      ...unpaidOrders.map((order) {
                        final date = DateFormat(
                          'MMM dd',
                        ).format(DateTime.parse(order['created_at']));
                        final amount =
                            double.tryParse(order['total_amount'].toString()) ??
                            0;
                        return DropdownMenuItem<int>(
                          value: order['id'],
                          child: Text(
                            'Order #${order['id']} - $date (KES $amount)',
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setDialogState(() {
                        selectedOrderId = val;
                        if (val != null) {
                          // Auto-fill amount from order
                          final order = unpaidOrders.firstWhere(
                            (o) => o['id'] == val,
                          );
                          amountController.text = order['total_amount']
                              .toString();
                        } else {
                          amountController.clear();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount (KES)',
                      border: OutlineInputBorder(),
                      prefixText: 'KES ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey(method),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: method,
                    items:
                        ['Cash', 'M-Pesa', 'Bank Transfer', 'Cheque', 'Other']
                            .map(
                              (m) => DropdownMenuItem(value: m, child: Text(m)),
                            )
                            .toList(),
                    onChanged: (val) => setDialogState(() => method = val!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final amount = double.tryParse(amountController.text);
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid amount'),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(dialogContext); // Close dialog

                  debugPrint('--- Payment Submission Started ---');
                  debugPrint('Customer: $customerId');
                  debugPrint('Amount: $amount');
                  debugPrint('Method: $method');
                  debugPrint('Linked Order: $selectedOrderId');

                  try {
                    await _apiService.addCustomerPayment(
                      customerId,
                      amount,
                      method,
                      notesController.text,
                      orderId: selectedOrderId,
                    );

                    debugPrint('Payment Success!');

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Payment recorded successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );

                    // Refresh Data
                    debugPrint('Refreshing customer data...');
                    _loadCustomers();
                    final data = await _apiService.getCustomers();
                    setState(() {
                      _customers = data;
                      final updated = _customers.firstWhere(
                        (c) => c['id'] == customerId,
                        orElse: () => null,
                      );
                      if (updated != null) _selectedCustomer = updated;
                      _loadTransactions(customerId);
                    });
                  } catch (e) {
                    debugPrint('PAYMENT ERROR: $e');
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error recording payment: $e')),
                    );
                  }
                },
                child: const Text('Confirm Payment'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final format = NumberFormat("#,##0.00");

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // LEFT PANEL: Customer List
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
                                  hintText: 'Search customers...',
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
                              onPressed: _startCreating,
                              icon: const Icon(Icons.add),
                              tooltip: 'New Customer',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.teal,
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
                    child: _customers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 64,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No customers yet',
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
                            itemCount: _customers.length,
                            separatorBuilder: (ctx, i) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final customer = _customers[index];
                              final isSelected =
                                  _selectedCustomer?['id'] == customer['id'];
                              final debt =
                                  double.tryParse(
                                    customer['current_debt'].toString(),
                                  ) ??
                                  0;
                              final wallet =
                                  double.tryParse(
                                    customer['wallet_balance'].toString(),
                                  ) ??
                                  0;
                              final netBalance = wallet - debt;

                              return InkWell(
                                onTap: () => _onSelectCustomer(customer),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.teal[50]
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.teal
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
                                            ? Colors.teal[100]
                                            : Colors.grey[100],
                                        child: Text(
                                          customer['name'][0].toUpperCase(),
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.teal[900]
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
                                              customer['name'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text(
                                                  netBalance < 0
                                                      ? 'Debt: KES ${format.format(netBalance.abs())}'
                                                      : 'Wallet: KES ${format.format(netBalance)}',
                                                  style: TextStyle(
                                                    color: netBalance < 0
                                                        ? Colors.red
                                                        : Colors.green[700],
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
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
                                            _onSelectCustomer(customer);
                                            _startEditing();
                                          }
                                          if (value == 'delete') {
                                            _deleteCustomer(customer['id']);
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
            flex: 5,
            child: Container(
              color: Colors.grey[50],
              child: _isEditing
                  ? CustomerFormPanel(
                      key: ValueKey(
                        _selectedCustomer?['id'] ?? 'new',
                      ), // Force rebuild on switch
                      customer: _selectedCustomer,
                      onSave: _handleFormSave,
                      onCancel: _cancelForm,
                    )
                  : _selectedCustomer == null
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
                            'Select a customer to view details',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _startCreating,
                            icon: const Icon(Icons.add),
                            label: const Text('Or Create New Customer'),
                          ),
                        ],
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Column(
                          children: [
                            // Header Box
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
                                      color: Colors.teal[50],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.teal,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedCustomer!['name'],
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
                                              Icons.phone_android,
                                              size: 16,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${_selectedCustomer!['phone'] ?? 'N/A'}${_selectedCustomer!['alt_phone'] != null && _selectedCustomer!['alt_phone'].isNotEmpty ? ' / ${_selectedCustomer!['alt_phone']}' : ''}',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.location_on_outlined,
                                              size: 16,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                _selectedCustomer!['address'] ??
                                                    'No Address',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
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
                                            party: _selectedCustomer!,
                                            transactions: _transactions,
                                            type: 'Customer',
                                            showDetails: showDetails,
                                          );
                                        },
                                        icon: const Icon(Icons.print),
                                        tooltip: 'Print Statement',
                                      ),
                                      IconButton(
                                        onPressed: () async {
                                          final phone =
                                              _selectedCustomer!['phone']
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

                                          // 1. Ask User: Statement (Text) or Reminder (Image)
                                          final choice = await showDialog<String>(
                                            context: context,
                                            builder: (ctx) => SimpleDialog(
                                              title: const Text(
                                                'Share Options',
                                              ),
                                              children: [
                                                SimpleDialogOption(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        ctx,
                                                        'statement',
                                                      ),
                                                  child: const Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          vertical: 12,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.message,
                                                          color: Colors.blue,
                                                        ),
                                                        SizedBox(width: 12),
                                                        Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              'Share Statement Message',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                            Text(
                                                              'Send text via WhatsApp',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color:
                                                                    Colors.grey,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                const Divider(),
                                                SimpleDialogOption(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        ctx,
                                                        'reminder',
                                                      ),
                                                  child: const Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          vertical: 12,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.image,
                                                          color: Colors.purple,
                                                        ),
                                                        SizedBox(width: 12),
                                                        Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              'Share Visual Reminder',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                            Text(
                                                              'Generate & share image',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color:
                                                                    Colors.grey,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (choice == null) return;

                                          // 2. Fetch Settings for Templates
                                          // Show loading indicator
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Preparing content...',
                                              ),
                                              duration: Duration(seconds: 1),
                                            ),
                                          );

                                          Map<String, String> settings = {};
                                          try {
                                            settings = await _settingsService
                                                .fetchSettings();
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Warning: Using default templates. Error: $e',
                                                  ),
                                                ),
                                              );
                                            }
                                          }

                                          final debt =
                                              double.tryParse(
                                                _selectedCustomer!['current_debt']
                                                        ?.toString() ??
                                                    '0',
                                              ) ??
                                              0;
                                          final formattedDebt = format.format(
                                            debt,
                                          );
                                          final customerName =
                                              _selectedCustomer!['name'];

                                          if (choice == 'statement') {
                                            // STATEMENT (Text)
                                            String template =
                                                settings['statement_message_template'] ??
                                                'Hello {name}, your current outstanding balance is KES {balance}. Please review your statement.';

                                            final message = template
                                                .replaceAll(
                                                  '{name}',
                                                  customerName,
                                                )
                                                .replaceAll(
                                                  '{balance}',
                                                  formattedDebt,
                                                );

                                            final url = Uri.parse(
                                              'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
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
                                          } else {
                                            // REMINDER (Image)
                                            // Allow dialog to fully close and UI to settle
                                            await Future.delayed(
                                              const Duration(milliseconds: 500),
                                            );

                                            try {
                                              if (!context.mounted) return;

                                              // Capture Context for Theme/MediaQuery
                                              final theme = Theme.of(context);
                                              final mediaQuery = MediaQuery.of(
                                                context,
                                              );

                                              final imageBytes = await _screenshotController
                                                  .captureFromWidget(
                                                    Theme(
                                                      data: theme,
                                                      child: MediaQuery(
                                                        data: mediaQuery,
                                                        child: Directionality(
                                                          textDirection: ui
                                                              .TextDirection
                                                              .ltr,
                                                          child: Material(
                                                            child: ReminderCard(
                                                              customer:
                                                                  _selectedCustomer!,
                                                              settings:
                                                                  settings,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    delay: const Duration(
                                                      milliseconds: 100,
                                                    ),
                                                    context:
                                                        context, // Use context to inherit/bootstrap
                                                  );

                                              final directory =
                                                  await getTemporaryDirectory();
                                              final imagePath =
                                                  '${directory.path}/reminder_${DateUtils.dateOnly(DateTime.now()).millisecondsSinceEpoch}.png';
                                              final imageFile = File(imagePath);
                                              await imageFile.writeAsBytes(
                                                imageBytes,
                                              );

                                              String template =
                                                  settings['reminder_message_template'] ??
                                                  'Hello {name}, this is a friendly reminder that you have an outstanding balance of KES {balance}.';
                                              final caption = template
                                                  .replaceAll(
                                                    '{name}',
                                                    customerName,
                                                  )
                                                  .replaceAll(
                                                    '{balance}',
                                                    formattedDebt,
                                                  );

                                              // ignore: deprecated_member_use
                                              await Share.shareXFiles([
                                                XFile(imagePath),
                                              ], text: caption);
                                            } catch (e) {
                                              debugPrint(
                                                'Error sharing reminder: $e',
                                              );
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Error sharing reminder: $e',
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
                                          }
                                        },
                                        icon: const Icon(Icons.share),
                                        tooltip: 'Share',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 16),
                                  // Financial Stats Card
                                  Builder(
                                    builder: (context) {
                                      final debt =
                                          double.tryParse(
                                            _selectedCustomer!['current_debt']
                                                .toString(),
                                          ) ??
                                          0;
                                      final wallet =
                                          double.tryParse(
                                            _selectedCustomer!['wallet_balance']
                                                .toString(),
                                          ) ??
                                          0;
                                      final netBalance = wallet - debt;
                                      final isPositive = netBalance >= 0;

                                      return Container(
                                        constraints: const BoxConstraints(
                                          minWidth: 100,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isPositive
                                              ? Colors.green[50]
                                              : Colors.red[50],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: isPositive
                                                ? Colors.green[100]!
                                                : Colors.red[100]!,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              isPositive
                                                  ? 'Wallet Balance'
                                                  : 'Current Debt',
                                              style: TextStyle(
                                                color: isPositive
                                                    ? Colors.green[900]
                                                    : Colors.red[900],
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            FittedBox(
                                              child: Text(
                                                'KES ${format.format(isPositive ? netBalance : netBalance.abs())}',
                                                style: TextStyle(
                                                  color: isPositive
                                                      ? Colors.green[700]
                                                      : Colors.red[700],
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),

                            // Transaction List
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
                                            Icons.history_edu,
                                            size: 48,
                                            color: Colors.grey[300],
                                          ),
                                          const SizedBox(height: 16),
                                          const Text(
                                            'No transaction history',
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.all(16),
                                      itemCount: _transactions.length,
                                      itemBuilder: (context, index) {
                                        final item = _transactions[index];
                                        final isPayment =
                                            item['type'] == 'payment';
                                        final amount =
                                            double.tryParse(
                                              item['amount'].toString(),
                                            ) ??
                                            0;
                                        final date = DateFormat(
                                          'MMM dd, yyyy HH:mm',
                                        ).format(DateTime.parse(item['date']));

                                        return Card(
                                          elevation: 0,
                                          color: isPayment
                                              ? Colors.green[50]
                                              : Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            side: BorderSide(
                                              color: isPayment
                                                  ? Colors.green[100]!
                                                  : Colors.grey[200]!,
                                            ),
                                          ),
                                          margin: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          child: ListTile(
                                            onTap: () {
                                              if (!isPayment) {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) =>
                                                      TransactionDetailsDialog(
                                                        transactionId:
                                                            item['id'],
                                                        type: 'order',
                                                        title: 'Sales Invoice',
                                                      ),
                                                );
                                              }
                                            },
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
                                                    ? Icons
                                                          .monetization_on_outlined
                                                    : Icons
                                                          .shopping_bag_outlined,
                                                color: isPayment
                                                    ? Colors.green
                                                    : Colors.blue,
                                              ),
                                            ),
                                            title: Text(
                                              isPayment
                                                  ? 'Payment Received${item['method'] != null ? ' (${item['method']})' : ''}'
                                                  : 'Order #${item['id']}',
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
                                                    item['notes'] != null)
                                                  Text(
                                                    item['notes'],
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
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
                                                      color:
                                                          item['status'] ==
                                                              'completed'
                                                          ? Colors.green[100]
                                                          : Colors.orange[100],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      (item['status'] ?? '')
                                                          .toUpperCase(),
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            item['status'] ==
                                                                'completed'
                                                            ? Colors.green[800]
                                                            : Colors
                                                                  .orange[900],
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
                        Positioned(
                          bottom: 24,
                          right: 24,
                          child: FloatingActionButton.extended(
                            onPressed: _showPaymentDialog,
                            icon: const Icon(Icons.attach_money),
                            label: const Text('Receive Payment'),
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
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
