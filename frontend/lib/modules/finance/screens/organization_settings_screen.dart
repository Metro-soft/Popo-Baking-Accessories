import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';

class OrganizationSettingsScreen extends StatefulWidget {
  const OrganizationSettingsScreen({super.key});

  @override
  State<OrganizationSettingsScreen> createState() =>
      _OrganizationSettingsScreenState();
}

class _OrganizationSettingsScreenState
    extends State<OrganizationSettingsScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _departments = [];
  List<dynamic> _roles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    try {
      final depts = await _api.getDepartments();
      final roles = await _api.getRoles();
      if (mounted) {
        setState(() {
          _departments = depts;
          _roles = roles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addDepartment() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Department'),
        content: TextFormField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Department Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.isNotEmpty) {
                try {
                  await _api.createDepartment(ctrl.text);
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  _loadMetadata();
                } catch (e) {
                  /* Handle error */
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDepartment(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Department?'),
        content: const Text('This will ideally delete logic here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _api.deleteDepartment(id);
      _loadMetadata();
    }
  }

  Future<void> _addRole() async {
    final nameCtrl = TextEditingController();
    int? selectedDeptId;

    // Auto-select first department if available
    if (_departments.isNotEmpty) {
      selectedDeptId = _departments.first['id'];
    }

    final List<String> allPermissions = [
      'sales',
      'inventory',
      'finance',
      'settings',
      'reports',
      'dispatch',
      'customers',
      'suppliers',
      'admin',
    ];
    List<String> selectedPermissions = [];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Job Role'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Role Title'),
                ),
                DropdownButtonFormField<int>(
                  initialValue: selectedDeptId,
                  decoration: const InputDecoration(labelText: 'Department'),
                  items: _departments.map<DropdownMenuItem<int>>((d) {
                    return DropdownMenuItem(
                      value: d['id'],
                      child: Text(d['name']),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => selectedDeptId = val),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Permissions:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Wrap(
                  spacing: 8,
                  children: allPermissions.map((perm) {
                    final isSelected = selectedPermissions.contains(perm);
                    return FilterChip(
                      label: Text(perm.toUpperCase()),
                      selected: isSelected,
                      onSelected: (bool selected) {
                        setState(() {
                          if (selected) {
                            selectedPermissions.add(perm);
                          } else {
                            selectedPermissions.remove(perm);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty && selectedDeptId != null) {
                  try {
                    await _api.createRole(
                      nameCtrl.text,
                      selectedDeptId!,
                      selectedPermissions,
                    );
                    if (!ctx.mounted) return;
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    _loadMetadata();
                  } catch (e) {
                    // Check if mounted on the *screen* context before showing snackbar,
                    // or use a global key, but here simple checking 'mounted' (of State) is best effort
                    if (mounted) {
                      ScaffoldMessenger.of(
                        this.context,
                      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
                    }
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteRole(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Role?'),
        content: const Text(
          'Are you sure? This relies on backend cascade logic.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _api.deleteRole(id);
      if (mounted) _loadMetadata();
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
        title: const Text(
          'Organization Settings',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Departments Column
            Expanded(
              child: _buildSectionCard(
                title: 'Departments',
                icon: Icons.business,
                color: Colors.blue,
                action: IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.blue),
                  onPressed: _addDepartment,
                ),
                content: _departments.isEmpty
                    ? _buildEmptyState('No departments')
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _departments.length,
                        separatorBuilder: (c, i) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final d = _departments[i];
                          return ListTile(
                            title: Text(d['name']),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () => _deleteDepartment(d['id']),
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(width: 16),
            // Job Roles Column
            Expanded(
              child: _buildSectionCard(
                title: 'Job Roles',
                icon: Icons.badge,
                color: Colors.purple,
                action: IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.purple),
                  onPressed: _addRole,
                ),
                content: _roles.isEmpty
                    ? _buildEmptyState('No roles')
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _roles.length,
                        separatorBuilder: (c, i) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final r = _roles[i];
                          // Find dept name
                          final dept = _departments.firstWhere(
                            (d) => d['id'] == r['department_id'],
                            orElse: () => {'name': 'Unknown'},
                          )['name'];
                          return ListTile(
                            title: Text(r['name']),
                            subtitle: Text(
                              dept,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () => _deleteRole(r['id']),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget content,
    required Widget action,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                action,
              ],
            ),
          ),
          const Divider(height: 1),
          content,
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(msg, style: TextStyle(color: Colors.grey.shade400)),
      ),
    );
  }
}
