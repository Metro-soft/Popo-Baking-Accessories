import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';

import '../widgets/employee_detail_panel.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  final ApiService _api = ApiService();

  // Data State
  List<dynamic> _employees = [];
  List<dynamic> _filteredEmployees = [];
  List<dynamic> _departments = [];
  List<dynamic> _roles = [];
  List<dynamic> _locations = [];
  bool _isLoading = true;

  // Selection State
  Map<String, dynamic>? _selectedEmployee;
  final TextEditingController _searchController = TextEditingController();

  // Editing State (Overlay)
  Map<String, dynamic>? _editingPayItem;
  bool _isEditingEmployee = false;
  bool _isAddingEmployee = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredEmployees = List.from(_employees);
      } else {
        _filteredEmployees = _employees.where((e) {
          final name = e['name'].toString().toLowerCase();
          final role = e['role']?.toString().toLowerCase() ?? '';
          return name.contains(query) || role.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadData() async {
    try {
      final emps = await _api.getEmployees();
      final depts = await _api.getDepartments();
      final roles = await _api.getRoles();
      final locs = await _api.getLocations();
      if (mounted) {
        setState(() {
          _employees = emps;
          _filteredEmployees = emps;
          _departments = depts;
          _roles = roles;
          _locations = locs;
          _isLoading = false;

          // Maintain selection if possible
          if (_selectedEmployee != null) {
            final updated = _employees.firstWhere(
              (e) => e['id'] == _selectedEmployee!['id'],
              orElse: () => null,
            );
            if (updated != null) {
              _selectedEmployee = updated;
            } else {
              _selectedEmployee = null;
              _isEditingEmployee = false;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEmployeeDialog([Map<String, dynamic>? emp]) {
    setState(() {
      if (emp == null) {
        _isAddingEmployee = true;
        _selectedEmployee = null;
      } else {
        _isEditingEmployee = true;
      }
      _editingPayItem = null;
    });
  }

  Future<void> _saveEmployee(Map<String, dynamic> data) async {
    try {
      if (_isAddingEmployee) {
        // Create
        await _api.createEmployee(data);
        await _loadData();
        setState(() => _isAddingEmployee = false);
      } else if (_isEditingEmployee && _selectedEmployee != null) {
        // Update
        await _api.updateEmployee(_selectedEmployee!['id'], data);
        await _loadData();
        setState(() => _isEditingEmployee = false);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee saved successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _savePayItem(double bonus, double deductions) async {
    if (_editingPayItem == null) return;
    try {
      await _api.updatePayrollItem(_editingPayItem!['id'], bonus, deductions);
      if (!mounted) return;
      setState(() {
        _editingPayItem = null;
        // Trigger generic rebuild to update history list key in Child
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment updated')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteEmployee(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Employee?'),
        content: const Text('This action cannot be undone.'),
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
        await _api.deleteEmployee(id);
        if (_selectedEmployee?['id'] == id) {
          setState(() => _selectedEmployee = null);
        }
        await _loadData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Payroll Management'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: false,
        actions: [],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // LEFT PANEL: Employee List (Flex 3)
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  // Search & Add Bar
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search employees...',
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
                          onPressed: () => _showEmployeeDialog(),
                          icon: const Icon(Icons.add),
                          tooltip: 'Add Employee',
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFA01B2D),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // List
                  Expanded(
                    child: _filteredEmployees.isEmpty
                        ? Center(
                            child: Text(
                              'No employees found',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _filteredEmployees.length,
                            separatorBuilder: (_, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final emp = _filteredEmployees[i];
                              final isSelected =
                                  _selectedEmployee?['id'] == emp['id'];
                              final isSplit =
                                  emp['payment_preference'] == 'SPLIT';

                              return InkWell(
                                onTap: () => setState(() {
                                  _selectedEmployee = emp;
                                  _isAddingEmployee =
                                      false; // Switch to view mode
                                  _isEditingEmployee = false;
                                }),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(
                                            0xFFA01B2D,
                                          ).withValues(alpha: 0.05)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFFA01B2D)
                                          : Colors.grey[200]!,
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: isSplit
                                            ? Colors.orange.shade50
                                            : Colors.pink.shade50,
                                        child: Text(
                                          emp['name'][0],
                                          style: TextStyle(
                                            color: isSplit
                                                ? Colors.orange
                                                : Colors.pink,
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
                                              emp['name'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              emp['role'] ?? 'No Role',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 14,
                                          color: Color(0xFFA01B2D),
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

          // RIGHT PANEL: Details (Flex 5)
          Expanded(
            flex: 5,
            child: EmployeeDetailPanel(
              selectedEmployee: _selectedEmployee,
              isAddingEmployee: _isAddingEmployee,
              isEditingEmployee: _isEditingEmployee,
              editingPayItem: _editingPayItem,
              departments: _departments,
              roles: _roles,
              locations: _locations,
              onCancelAdd: () => setState(() => _isAddingEmployee = false),
              onCancelEdit: () => setState(() => _isEditingEmployee = false),
              onSaveEmployee: _saveEmployee,
              onDeleteEmployee: _deleteEmployee,
              onEditEmployeeRequest: (emp) => _showEmployeeDialog(emp),
              onEditPayItemRequest: (item) =>
                  setState(() => _editingPayItem = item),
              onCancelEditPayItem: () => setState(() => _editingPayItem = null),
              onSavePayItem: _savePayItem,
              onRefresh: () => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }
}
