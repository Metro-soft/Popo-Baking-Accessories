import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_service.dart';
import 'manage_categories_screen.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = false;
  List<dynamic> _expenses = [];
  List<dynamic> _categories = [];

  // Filters
  DateTimeRange? _dateRange;
  int? _selectedCategoryId;
  final TextEditingController _searchCtrl = TextEditingController();

  double get _totalExpenses => _expenses.fold(
    0.0,
    (sum, e) => sum + double.parse(e['amount'].toString()),
  );

  double get _totalDirect => _expenses
      .where((e) => e['category_type'] == 'direct')
      .fold(0.0, (sum, e) => sum + double.parse(e['amount'].toString()));

  double get _totalIndirect => _expenses
      .where((e) => e['category_type'] == 'indirect')
      .fold(0.0, (sum, e) => sum + double.parse(e['amount'].toString()));

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadCategories(), _loadExpenses()]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadCategories() async {
    try {
      final data = await _api.getExpenseCategories();
      setState(() => _categories = data);
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  Future<void> _loadExpenses() async {
    try {
      final startDate = _dateRange != null
          ? DateFormat('yyyy-MM-dd').format(_dateRange!.start)
          : null;
      final endDate = _dateRange != null
          ? DateFormat('yyyy-MM-dd').format(_dateRange!.end)
          : null;

      final data = await _api.getExpenses(
        startDate: startDate,
        endDate: endDate,
        categoryId: _selectedCategoryId,
        search: _searchCtrl.text,
      );
      setState(() {
        _expenses = data;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteExpense(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _api.deleteExpense(id);
        _loadExpenses();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
        }
      }
    }
  }

  void _showAddExpenseModal() {
    showDialog(
      context: context,
      builder: (ctx) => _AddExpenseDialog(categories: _categories),
    ).then((val) {
      if (val == true) _loadExpenses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Expenses Dashboard',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ManageCategoriesScreen(),
                ),
              ).then((_) => _loadCategories()); // Refresh cats on return
            },
            icon: const Icon(Icons.settings),
            label: const Text('Manage Categories'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Row(
        children: [
          // 1. LEFT COLUMN: Category Sidebar (Full Height)
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Column(
                children: [
                  _buildCategoryTile(null, 'All Expenses', Icons.dashboard),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        _buildCategorySection(
                          'Direct Expenses (COGS)',
                          'direct',
                        ),
                        const Divider(),
                        _buildCategorySection(
                          'Indirect Expenses (OpEx)',
                          'indirect',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. RIGHT COLUMN: Content (Header + List)
          Expanded(
            flex: 3,
            child: Column(
              children: [
                // PREMIUM DASHBOARD HEADER
                _buildDashboardHeader(),
                const Divider(height: 1),

                // FILTERS
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Search description or ref...',
                            prefixIcon: const Icon(Icons.search),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                          ),
                          onSubmitted: (_) => _loadExpenses(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.date_range),
                        onPressed: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => _dateRange = picked);
                            _loadExpenses();
                          }
                        },
                        tooltip: 'Filter by Date',
                      ),
                      if (_dateRange != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            setState(() => _dateRange = null);
                            _loadExpenses();
                          },
                          tooltip: 'Clear Date Filter',
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // LIST OF TRANSACTIONS
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _expenses.isEmpty
                      ? const Center(
                          child: Text(
                            'No expenses found.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _expenses.length,
                          separatorBuilder: (ctx, i) =>
                              const SizedBox(height: 12),
                          itemBuilder: (ctx, index) {
                            final item = _expenses[index];
                            return _buildExpenseCard(item);
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseModal,
        backgroundColor: const Color(0xFFA01B2D),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Expense', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildDashboardHeader() {
    double total = _totalExpenses;
    double direct = _totalDirect;
    double indirect = _totalIndirect;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          _buildSummaryCard('Total', total, Colors.black87),
          const SizedBox(width: 12),
          _buildSummaryCard('Direct (COGS)', direct, Colors.teal),
          const SizedBox(width: 12),
          _buildSummaryCard('Indirect (OpEx)', indirect, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'KES ${NumberFormat('#,##0').format(amount)}',
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(String title, String type) {
    final cats = _categories.where((c) => c['type'] == type).toList();
    if (cats.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey[500],
            ),
          ),
        ),
        ...cats.map(
          (c) => _buildCategoryTile(
            c['id'],
            c['name'],
            _getCategoryIcon(c['name']),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryTile(int? id, String label, IconData icon) {
    final isSelected = _selectedCategoryId == id;
    return InkWell(
      onTap: () {
        setState(() => _selectedCategoryId = id);
        _loadExpenses();
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFA01B2D).withValues(alpha: 0.05)
              : Colors.transparent,
          border: isSelected
              ? const Border(
                  right: BorderSide(color: Color(0xFFA01B2D), width: 3),
                )
              : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        width: double.infinity,
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? const Color(0xFFA01B2D) : Colors.grey[600],
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFFA01B2D) : Colors.black87,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseCard(dynamic item) {
    final date = DateTime.parse(item['date']);
    final amount = double.parse(item['amount'].toString());
    final isDirect = item['category_type'] == 'direct';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isDirect ? Colors.teal[50] : Colors.orange[50],
          child: Icon(
            _getCategoryIcon(item['category_name']),
            color: isDirect ? Colors.teal[700] : Colors.orange[700],
            size: 20,
          ),
        ),
        title: Text(
          item['description'] ?? item['category_name'],
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${DateFormat('MMM d').format(date)} • ${item['category_name']}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isDirect
                        ? Colors.teal.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isDirect ? 'Direct' : 'Indirect',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isDirect ? Colors.teal[800] : Colors.orange[800],
                    ),
                  ),
                ),
              ],
            ),
            if (item['reference_code'] != null &&
                item['reference_code'].toString().isNotEmpty)
              Text(
                'Ref: ${item['reference_code']}',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'KES ${NumberFormat('#,##0.00').format(amount)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              item['payment_method'] ?? 'Cash',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
        onLongPress: () => _deleteExpense(item['id']),
      ),
    );
  }

  IconData _getCategoryIcon(String? categoryName) {
    if (categoryName == null) {
      return Icons.receipt;
    }
    final name = categoryName.toLowerCase();
    if (name.contains('rent')) {
      return Icons.business;
    }
    if (name.contains('util')) {
      return Icons.lightbulb_outline;
    }
    if (name.contains('salary') || name.contains('payroll')) {
      return Icons.people_outline;
    }
    if (name.contains('transport')) {
      return Icons.local_shipping_outlined;
    }
    if (name.contains('packag')) {
      return Icons.card_giftcard;
    }
    if (name.contains('mainten')) {
      return Icons.build_outlined;
    }
    if (name.contains('market')) {
      return Icons.campaign_outlined;
    }
    if (name.contains('fee')) {
      return Icons.account_balance_wallet_outlined;
    }
    if (name.contains('material')) {
      return Icons.inventory_2_outlined;
    }
    return Icons.receipt_long_outlined;
  }
}

class _AddExpenseDialog extends StatefulWidget {
  final List<dynamic> categories;
  const _AddExpenseDialog({required this.categories});

  @override
  State<_AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<_AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _api = ApiService();
  bool _isSaving = false;

  DateTime _selectedDate = DateTime.now();
  int? _categoryId;
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _refCtrl = TextEditingController();
  String _paymentMethod = 'Cash';

  Future<void> _submit({bool addAnother = false}) async {
    if (!_formKey.currentState!.validate()) return;

    if (_categoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _api.createExpense({
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'category_id': _categoryId,
        'description': _descCtrl.text,
        'amount': double.parse(_amountCtrl.text),
        'payment_method': _paymentMethod,
        'reference_code': _refCtrl.text,
        'branch_id': 1,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Expense saved${addAnother ? ". Ready for next." : ""}',
          ),
        ),
      );

      if (addAnother) {
        setState(() {
          _isSaving = false;
          _amountCtrl.clear();
          _descCtrl.clear();
          _refCtrl.clear();
          // Keep Date, Category, Payment Method
        });
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Expense'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(DateFormat('MMM d, yyyy').format(_selectedDate)),
                ),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<int>(
                initialValue: _categoryId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: widget.categories
                    .map(
                      (c) => DropdownMenuItem<int>(
                        value: c['id'],
                        child: Text('${c['name']} (${c['type']})'),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _categoryId = val!),
                validator: (val) => val == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (KES)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  if (double.tryParse(val) == null) return 'Invalid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description / Payee',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                decoration: const InputDecoration(
                  labelText: 'Payment Method',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payment),
                ),
                items: ['Cash', 'M-Pesa', 'Bank Transfer', 'Cheque']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => setState(() => _paymentMethod = val!),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _refCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ref Code (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.receipt),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        if (!_isSaving)
          TextButton(
            onPressed: () => _submit(addAnother: true),
            child: const Text('Save & Add Another'),
          ),
        ElevatedButton(
          onPressed: _isSaving ? null : () => _submit(addAnother: false),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFA01B2D),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
