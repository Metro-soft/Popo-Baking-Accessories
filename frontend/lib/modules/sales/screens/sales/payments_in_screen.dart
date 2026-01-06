import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import 'package:intl/intl.dart';

class PaymentsInScreen extends StatefulWidget {
  const PaymentsInScreen({super.key});

  @override
  State<PaymentsInScreen> createState() => _PaymentsInScreenState();
}

class _PaymentsInScreenState extends State<PaymentsInScreen> {
  final ApiService _apiService = ApiService();
  final NumberFormat _currency = NumberFormat.currency(
    symbol: 'KES ',
    decimalDigits: 0,
  );
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy HH:mm');

  List<dynamic> _allPayments = [];
  List<dynamic> _filteredPayments = [];
  bool _isLoading = false;

  DateTimeRange? _selectedDateRange;
  List<dynamic> _branches = [];
  int? _selectedBranchId; // Null means All Branches

  final ScrollController _verticalController = ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadBranches();
    _loadPayments();
  }

  Future<void> _loadBranches() async {
    try {
      final branches = await _apiService.getBranches();
      if (mounted) {
        setState(() {
          _branches = branches;
        });
      }
    } catch (e) {
      debugPrint('Error loading branches: $e');
    }
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.getPaymentsIn(
        startDate: _selectedDateRange?.start.toIso8601String(),
        endDate: _selectedDateRange?.end.toIso8601String(),
        branchId: _selectedBranchId,
      );
      setState(() {
        _allPayments = data;
        _filteredPayments = data;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading payments: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
      _loadPayments();
    }
  }

  void _filter(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredPayments = _allPayments;
      } else {
        final q = query.toLowerCase();
        _filteredPayments = _allPayments.where((p) {
          final customer = (p['customer_name'] ?? '').toString().toLowerCase();
          final notes = (p['notes'] ?? '').toString().toLowerCase();
          final method = (p['method'] ?? '').toString().toLowerCase();
          return customer.contains(q) ||
              notes.contains(q) ||
              method.contains(q);
        }).toList();
      }
    });
  }

  double get _totalReceived {
    return _filteredPayments.fold(0.0, (sum, item) {
      return sum + (double.tryParse(item['amount'].toString()) ?? 0.0);
    });
  }

  double _totalByMethod(String methodPart) {
    return _filteredPayments
        .where((p) {
          final m = (p['method'] ?? '').toString().toLowerCase();
          // 'wallet' matches 'wallet deposit' or just 'wallet'
          return m.contains(methodPart.toLowerCase());
        })
        .fold(0.0, (sum, item) {
          return sum + (double.tryParse(item['amount'].toString()) ?? 0.0);
        });
  }

  // --- Premium UI Widgets ---

  Widget _buildSummaryCard(
    String title,
    double amount,
    Color color, {
    bool isTotal = false,
  }) {
    return Container(
      width: isTotal ? 160 : 130,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isTotal
            ? LinearGradient(
                colors: [
                  color.withValues(alpha: 0.9),
                  color.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isTotal ? null : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: isTotal
            ? null
            : Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isTotal ? Colors.white : Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currency.format(amount),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isTotal ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Brand Colors
    const kPrimaryColor = Color(0xFFA01B2D);

    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background for contrast
      body: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            color: Colors.white,
            child: Column(
              children: [
                // Title & Summary Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Payments In',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: kPrimaryColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Track revenue from POS and Customer Debt payments',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Summary Cards
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildSummaryCard(
                            'TOTAL',
                            _totalReceived,
                            kPrimaryColor,
                            isTotal: true,
                          ),
                          const SizedBox(width: 12),
                          _buildSummaryCard(
                            'CASH',
                            _totalByMethod('cash'),
                            Colors.green[700]!,
                          ),
                          const SizedBox(width: 12),
                          _buildSummaryCard(
                            'MPESA',
                            _totalByMethod('mpesa'),
                            Colors.green[700]!,
                          ),
                          const SizedBox(width: 12),
                          _buildSummaryCard(
                            'WALLET',
                            _totalByMethod('wallet'),
                            Colors.blue[700]!,
                          ),
                          const SizedBox(width: 12),
                          _buildSummaryCard(
                            'BANK',
                            _totalByMethod('bank'),
                            Colors.purple[700]!,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Filter Bar
                Row(
                  children: [
                    // Search Field
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Icon(Icons.search, color: Colors.grey[500]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                onChanged: _filter,
                                decoration: const InputDecoration(
                                  hintText: 'Search customer, ref, method...',
                                  border: InputBorder.none,
                                  hintStyle: TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Dropdown: Branch
                    if (_branches.isNotEmpty) ...[
                      Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: _selectedBranchId,
                            hint: Text(
                              'All Branches',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.grey,
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('All Branches'),
                              ),
                              ..._branches.map((b) {
                                return DropdownMenuItem<int?>(
                                  value: b['id'],
                                  child: Text(b['name']),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedBranchId = val);
                              _loadPayments();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    // Date Filter
                    OutlinedButton.icon(
                      onPressed: _pickDateRange,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: Colors.grey[700],
                      ),
                      label: Text(
                        _selectedDateRange == null
                            ? 'All Dates'
                            : '${DateFormat('MMM dd').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd').format(_selectedDateRange!.end)}',
                        style: TextStyle(color: Colors.grey[900]),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Refresh Button
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadPayments,
                      tooltip: 'Refresh',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Data Table Section
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPayments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No payments found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : Scrollbar(
                    controller: _verticalController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    child: SingleChildScrollView(
                      controller: _verticalController,
                      padding: const EdgeInsets.all(24),
                      scrollDirection: Axis.vertical,
                      child: SizedBox(
                        width: double.infinity,
                        child: Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.grey[200]),
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              Colors.grey[100],
                            ),
                            dataRowColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (states.contains(WidgetState.hovered)) {
                                return Colors.red.withValues(alpha: 0.05);
                              }
                              return Colors.white;
                            }),
                            headingTextStyle: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                              fontSize: 13,
                            ),
                            dataRowMaxHeight: 60,
                            columnSpacing: 24,
                            columns: const [
                              DataColumn(label: Text('DATE & TIME')),
                              DataColumn(label: Text('CUSTOMER')),
                              DataColumn(label: Text('AMOUNT')),
                              DataColumn(label: Text('METHOD')),
                              DataColumn(label: Text('NOTES / REF')),
                            ],
                            rows: _filteredPayments.map((p) {
                              final date = DateTime.parse(
                                p['payment_date'].toString(),
                              ).toLocal();
                              final amount =
                                  double.tryParse(p['amount'].toString()) ??
                                  0.0;
                              final method = (p['method'] ?? 'Unknown')
                                  .toString()
                                  .toUpperCase();

                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      _dateFormat.format(date),
                                      style: TextStyle(
                                        color: Colors.grey[800],
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor: kPrimaryColor
                                              .withValues(alpha: 0.1),
                                          child: Text(
                                            (p['customer_name'] ?? 'U')
                                                .toString()
                                                .substring(0, 1)
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: kPrimaryColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          p['customer_name'] ?? 'Unknown',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      _currency.format(amount),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getMethodColor(
                                          method,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: _getMethodColor(
                                            method,
                                          ).withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Text(
                                        method,
                                        style: TextStyle(
                                          color: _getMethodColor(method),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      p['notes'] ?? '-',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Color _getMethodColor(String method) {
    if (method.contains('CASH')) return Colors.green[700]!;
    if (method.contains('MPESA')) return Colors.green[800]!;
    if (method.contains('WALLET')) return Colors.blue[700]!;
    if (method.contains('BANK')) return Colors.purple[700]!;
    return Colors.grey[700]!;
  }
}
