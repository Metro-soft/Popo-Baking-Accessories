import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = false;
  List<dynamic> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final data = await _api.getExpenseCategories();
      setState(() {
        _categories = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteCategory(int id, bool isSystem) async {
    if (isSystem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete default categories')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: const Text('Are you sure? This cannot be undone.'),
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
        await _api.deleteExpenseCategory(id);
        _loadCategories();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Category deleted')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  void _showAddCategoryDialog() {
    showDialog(
      context: context,
      builder: (ctx) => const _AddCategoryDialog(),
    ).then((val) {
      if (val == true) _loadCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Group by Type
    final direct = _categories.where((c) => c['type'] == 'direct').toList();
    final indirect = _categories.where((c) => c['type'] == 'indirect').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Categories'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSection('Direct Expenses (COGS)', direct, Colors.blue),
                const SizedBox(height: 24),
                _buildSection(
                  'Indirect Expenses (OpEx)',
                  indirect,
                  Colors.orange,
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCategoryDialog,
        label: const Text('New Category'),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFFA01B2D),
      ),
    );
  }

  Widget _buildSection(String title, List<dynamic> items, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 4, height: 20, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'No categories found.',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map(
                  (c) => Chip(
                    label: Text(c['name']),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey.shade300),
                    deleteIcon: c['is_system']
                        ? const Icon(Icons.lock, size: 16)
                        : const Icon(Icons.close, size: 16),
                    onDeleted: c['is_system']
                        ? null
                        : () => _deleteCategory(c['id'], c['is_system']),
                    deleteButtonTooltipMessage: c['is_system']
                        ? 'System Category'
                        : 'Delete',
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _AddCategoryDialog extends StatefulWidget {
  const _AddCategoryDialog();

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _api = ApiService();
  bool _isSaving = false;

  final TextEditingController _nameCtrl = TextEditingController();
  String _type = 'indirect';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await _api.createExpenseCategory(_nameCtrl.text, _type);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Category'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                border: OutlineInputBorder(),
              ),
              validator: (val) => val!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'direct', child: Text('Direct (COGS)')),
                DropdownMenuItem(
                  value: 'indirect',
                  child: Text('Indirect (OpEx)'),
                ),
              ],
              onChanged: (val) => setState(() => _type = val!),
            ),
            const SizedBox(height: 8),
            const Text(
              'Direct: Costs directly tied to production.\nIndirect: General overhead costs.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
