import 'package:flutter/material.dart';
import '../../../../core/services/api_service.dart';

class CustomerSelector extends StatefulWidget {
  final Function(Map<String, dynamic>?) onCustomerSelected;

  const CustomerSelector({super.key, required this.onCustomerSelected});

  @override
  State<CustomerSelector> createState() => _CustomerSelectorState();
}

class _CustomerSelectorState extends State<CustomerSelector> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<dynamic> _allCustomers = [];
  List<dynamic> _filteredCustomers = [];
  Map<String, dynamic>? _selectedCustomer;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    try {
      final customers = await _apiService.getCustomers();
      setState(() {
        _allCustomers = customers;
        _filteredCustomers = customers;
      });
    } catch (e) {
      // Handle error cleanly
      debugPrint('Error loading customers: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filter(String query) {
    setState(() {
      _filteredCustomers = _allCustomers.where((c) {
        final name = c['name'].toString().toLowerCase();
        final phone = c['phone']?.toString().toLowerCase() ?? '';
        final q = query.toLowerCase();
        return name.contains(q) || phone.contains(q);
      }).toList();
    });
  }

  Color _getCreditColor(Map<String, dynamic> c) {
    final debt = double.tryParse(c['current_debt'].toString()) ?? 0.0;
    final limit = double.tryParse(c['credit_limit'].toString()) ?? 5000.0;

    if (limit == 0) return Colors.grey;
    final ratio = debt / limit;

    if (ratio >= 0.9) return Colors.red;
    if (ratio >= 0.75) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedCustomer != null) {
      final c = _selectedCustomer!;
      final debt = double.tryParse(c['current_debt'].toString()) ?? 0.0;
      final limit = double.tryParse(c['credit_limit'].toString()) ?? 5000.0;
      final color = _getCreditColor(c);

      return Card(
        color: color.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: color),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          leading: Icon(Icons.person, color: color),
          title: Text(
            c['name'],
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'Debt: KES ${debt.toStringAsFixed(0)} / Limit: ${limit.toStringAsFixed(0)}',
          ),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() {
                _selectedCustomer = null;
                _searchCtrl.clear();
              });
              widget.onCustomerSelected(null);
            },
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            labelText: 'Search Customer (Name/Phone)',
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
            suffixIcon: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
          onChanged: _filter,
        ),
        if (_searchCtrl.text.isNotEmpty && _selectedCustomer == null)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filteredCustomers.length,
              itemBuilder: (ctx, i) {
                final c = _filteredCustomers[i];
                return ListTile(
                  title: Text(c['name']),
                  subtitle: Text(c['phone'] ?? 'No Phone'),
                  onTap: () {
                    setState(() => _selectedCustomer = c);
                    widget.onCustomerSelected(c);
                    _searchCtrl.clear();
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
