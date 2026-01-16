import 'package:flutter/material.dart';

class EmployeeFormWidget extends StatefulWidget {
  final Map<String, dynamic>? employee; // null = Add
  final List<dynamic> departments;
  final List<dynamic> roles;
  final List<dynamic> locations;
  final Function(Map<String, dynamic> data) onSave;
  final VoidCallback onCancel;

  const EmployeeFormWidget({
    super.key,
    this.employee,
    required this.departments,
    required this.roles,
    required this.locations,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<EmployeeFormWidget> createState() => _EmployeeFormWidgetState();
}

class _EmployeeFormWidgetState extends State<EmployeeFormWidget> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _salaryCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _advanceCtrl;

  String? _selectedDept;
  String? _selectedRole;
  int? _selectedBranchId;
  String _paymentPref = 'FULL';
  List<dynamic> _filteredRoles = [];

  @override
  void initState() {
    super.initState();
    final emp = widget.employee;
    _nameCtrl = TextEditingController(text: emp?['name']);
    _salaryCtrl = TextEditingController(text: emp?['base_salary']?.toString());
    _phoneCtrl = TextEditingController(text: emp?['phone']);
    _emailCtrl = TextEditingController(text: emp?['email']);
    _advanceCtrl = TextEditingController(
      text: emp?['fixed_advance_amount']?.toString() ?? '0',
    );

    _selectedBranchId =
        emp?['branch_id'] ??
        widget.locations.firstWhere(
          (l) => l['is_main'] == true,
          orElse: () => widget.locations.firstOrNull,
        )['id'];

    _paymentPref = emp?['payment_preference'] ?? 'FULL';
    _selectedDept = emp?['department'];

    // Validate dept exists
    if (_selectedDept != null &&
        !widget.departments.any((d) => d['name'] == _selectedDept)) {
      _selectedDept = null;
    }

    _selectedRole = emp?['role'];
    if (_selectedRole != null &&
        !widget.roles.any((r) => r['name'] == _selectedRole)) {
      _selectedRole = null;
    }

    if (_selectedDept != null) {
      _filterRoles();
      // Ensure the selected role actually belongs to the selected department
      if (_selectedRole != null &&
          !_filteredRoles.any((r) => r['name'] == _selectedRole)) {
        _selectedRole = null;
      }
    }
  }

  void _filterRoles() {
    if (_selectedDept == null) {
      _filteredRoles = [];
      return;
    }
    try {
      final deptId = widget.departments.firstWhere(
        (d) => d['name'] == _selectedDept,
      )['id'];
      _filteredRoles = widget.roles
          .where((r) => r['department_id'] == deptId)
          .toList();
    } catch (_) {
      _filteredRoles = [];
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _salaryCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _advanceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.employee == null
                          ? 'Add Employee'
                          : 'Edit Employee',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onCancel,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Name
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 15.5,
                    ),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                // Email
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 15.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Branch
                DropdownButtonFormField<int>(
                  dropdownColor: Colors.white,
                  isExpanded: true,
                  value: _selectedBranchId,
                  decoration: const InputDecoration(
                    labelText: 'Branch',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 15.5,
                    ),
                  ),
                  items: widget.locations.map<DropdownMenuItem<int>>((l) {
                    return DropdownMenuItem(
                      value: l['id'],
                      child: Text(
                        l['name'],
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedBranchId = val;
                      // Optional: Reset department or role if they are branch-specific later
                    });
                  },
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                // Department & Role Row
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        dropdownColor: Colors.white,
                        isExpanded: true,
                        initialValue: _selectedDept,
                        decoration: const InputDecoration(
                          labelText: 'Department',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 15.5,
                          ),
                        ),
                        items: widget.departments.map<DropdownMenuItem<String>>(
                          (d) {
                            return DropdownMenuItem(
                              value: d['name'],
                              child: Text(
                                d['name'],
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          },
                        ).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedDept = val;
                            _selectedRole = null;
                            _filterRoles();
                          });
                        },
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        dropdownColor: Colors.white,
                        isExpanded: true,
                        key: ValueKey('role_${_selectedDept ?? 'none'}'),
                        initialValue: _selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 15.5,
                          ),
                        ),
                        items: _filteredRoles.map<DropdownMenuItem<String>>((
                          r,
                        ) {
                          return DropdownMenuItem(
                            value: r['name'],
                            child: Text(
                              r['name'],
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedRole = val),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Salary
                TextFormField(
                  controller: _salaryCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Base Salary',
                    prefixText: 'KES ',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 15.5,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                // Payment Pref
                DropdownButtonFormField<String>(
                  dropdownColor: Colors.white,
                  initialValue: _paymentPref,
                  decoration: const InputDecoration(
                    labelText: 'Payment Preference',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 15.5,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'FULL',
                      child: Text(
                        'Full (End of Month)',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'SPLIT',
                      child: Text(
                        'Split (Mid-Month Advance)',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => _paymentPref = val!),
                ),

                if (_paymentPref == 'SPLIT') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _advanceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Fixed Advance Amount (Optional)',
                      helperText: 'Leave 0 to use 40% default',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 15.5,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],

                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 15.5,
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: widget.onCancel,
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          final data = {
                            'name': _nameCtrl.text,
                            'branch_id': _selectedBranchId,
                            'role': _selectedRole,
                            'department': _selectedDept,
                            'base_salary':
                                double.tryParse(_salaryCtrl.text) ?? 0,
                            'phone': _phoneCtrl.text,
                            'email': _emailCtrl.text,
                            'payment_preference': _paymentPref,
                            'fixed_advance_amount':
                                double.tryParse(_advanceCtrl.text) ?? 0,
                          };
                          widget.onSave(data);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA01B2D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Save Employee'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
