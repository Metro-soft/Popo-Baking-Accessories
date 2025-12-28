import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';

class CashManagementScreen extends StatefulWidget {
  const CashManagementScreen({super.key});

  @override
  State<CashManagementScreen> createState() => _CashManagementScreenState();
}

class _CashManagementScreenState extends State<CashManagementScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;

  // State
  Map<String, dynamic>? _shiftData; // { status, shift, currentBalance }
  final int _branchId = 1; // Default for MVP
  final int _userId = 1; // Default Admin

  // Controllers
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.getCashStatus(branchId: _branchId);
      if (mounted) {
        setState(() => _shiftData = data);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openShift() async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    setState(() => _isLoading = true);
    try {
      await _apiService.openShift(_branchId, _userId, amount);
      _amountController.clear();
      await _loadStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _closeShift() async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final notes = _reasonController.text;

    setState(() => _isLoading = true);
    try {
      await _apiService.closeCashShift(_branchId, amount, notes);
      _amountController.clear();
      _reasonController.clear();
      if (mounted) Navigator.pop(context); // Close dialog
      await _loadStatus(); // Refresh to show closed/summary
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shift Closed Successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addTransaction(String type) async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final reason = _reasonController.text;

    setState(() => _isLoading = true);
    try {
      await _apiService.addCashTransaction(
        _branchId,
        _userId,
        type,
        amount,
        reason,
      );
      _amountController.clear();
      _reasonController.clear();
      if (mounted) Navigator.pop(context);
      await _loadStatus();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transaction Added')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  void _showTransactionDialog(String type) {
    _amountController.clear();
    _reasonController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          type == 'expense'
              ? 'Add Expense'
              : (type == 'deposit' ? 'Add Deposit' : 'Withdrawal'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(labelText: 'Reason / Notes'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _addTransaction(type),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showCloseShiftDialog() {
    _amountController.clear();
    _reasonController.clear();
    final systemBalance = _shiftData?['currentBalance'] ?? '0.00';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close Shift / Z-Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expected Cash in Drawer: KES $systemBalance',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text('Enter Actual Counted Cash:'),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Actual Amount'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Notes / Variance Reason',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: _closeShift,
            child: const Text('CLOSE SHIFT'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final status = _shiftData?['status'];
    final shift = _shiftData?['shift'];
    final balance = _shiftData?['currentBalance'];

    return Scaffold(
      appBar: AppBar(title: const Text('Cash Management')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: status == 'closed'
            ? _buildOpenShiftUI()
            : _buildActiveShiftUI(shift, balance),
      ),
    );
  }

  Widget _buildOpenShiftUI() {
    return Center(
      child: Card(
        elevation: 4,
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_open, size: 64, color: Colors.green),
              const SizedBox(height: 20),
              const Text(
                'Start New Shift',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Opening Float Amount',
                  border: OutlineInputBorder(),
                  prefixText: 'KES ',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _openShift,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'OPEN SHIFT',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveShiftUI(dynamic shift, dynamic balance) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue[100]!),
          ),
          child: Column(
            children: [
              const Text(
                'SHIFT ACTIVE',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'KES $balance',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Text(
                'Estimated Cash in Drawer',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Started: ${shift['start_time'].toString().substring(0, 16)}',
                  ), // Simple format
                  const SizedBox(width: 20),
                  Text('Opening Float: KES ${shift['opening_balance']}'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Add Expense',
                Icons.receipt,
                Colors.orange,
                () => _showTransactionDialog('expense'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionButton(
                'Add Deposit',
                Icons.add_circle,
                Colors.green,
                () => _showTransactionDialog('deposit'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionButton(
                'Withdrawal',
                Icons.remove_circle,
                Colors.red,
                () => _showTransactionDialog('withdrawal'),
              ),
            ),
          ],
        ),

        const Spacer(),

        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton.icon(
            onPressed: _showCloseShiftDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.lock),
            label: const Text(
              'CLOSE SHIFT & PRINT Z-REPORT',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
