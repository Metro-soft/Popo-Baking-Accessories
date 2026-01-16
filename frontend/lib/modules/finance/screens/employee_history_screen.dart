import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/api_service.dart';
import '../services/payslip_generator.dart';

class EmployeeHistoryScreen extends StatelessWidget {
  final int employeeId;
  final String employeeName;

  const EmployeeHistoryScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('$employeeName - Payment History'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: EmployeeHistoryList(
        employeeId: employeeId,
        employeeName: employeeName,
        isEmbedded: false,
      ),
    );
  }
}

class EmployeeHistoryList extends StatefulWidget {
  final int employeeId;
  final String employeeName;
  final bool isEmbedded;
  final Function(Map<String, dynamic> item)?
  onEditItem; // Callback for parent handling

  const EmployeeHistoryList({
    super.key,
    required this.employeeId,
    required this.employeeName,
    this.isEmbedded = true,
    this.onEditItem,
  });

  @override
  State<EmployeeHistoryList> createState() => _EmployeeHistoryListState();
}

class _EmployeeHistoryListState extends State<EmployeeHistoryList> {
  final ApiService _api = ApiService();
  List<dynamic> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void didUpdateWidget(EmployeeHistoryList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.employeeId != oldWidget.employeeId) {
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final data = await _api.getEmployeeHistory(widget.employeeId);
      if (mounted) {
        setState(() {
          _history = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _editItem(Map<String, dynamic> item) {
    if (item['run_id'] == null) return;

    // Delegate to parent if callback provided
    if (widget.onEditItem != null) {
      widget.onEditItem!(item);
      return;
    }

    final bonusCtrl = TextEditingController(text: item['bonuses'].toString());
    final deductCtrl = TextEditingController(
      text: item['deductions'].toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Edit Pay: ${item['employee_name'] ?? widget.employeeName}',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Base Salary: ${item['base_salary']}'),
            const SizedBox(height: 10),
            TextFormField(
              controller: bonusCtrl,
              decoration: const InputDecoration(labelText: 'Bonus'),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              controller: deductCtrl,
              decoration: const InputDecoration(labelText: 'Deductions'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Note: This endpoint expects 'id' which is the payroll_item id
              // The history endpoint should return this as 'id' or we might need to verify
              await _api.updatePayrollItem(
                item['id'],
                double.tryParse(bonusCtrl.text) ?? 0,
                double.tryParse(deductCtrl.text) ?? 0,
              );
              if (!mounted) return;
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _loadHistory();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePdf(Map<String, dynamic> item) async {
    try {
      // Ensure we have employee_name for valid PDF generation
      Map<String, dynamic> safeItem = Map.from(item);
      safeItem['employee_name'] ??= widget.employeeName;

      await PayslipGenerator().generateAndPrint(
        safeItem,
        item['month'] ?? 'Unknown',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
    }
  }

  Future<void> _sharePayslip(Map<String, dynamic> item) async {
    // History item might not have phone number directly, checking keys
    // Assuming backend join provides it or we fallback to empty
    final phone = item['employee_phone']?.toString().replaceAll(' ', '') ?? '';
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No phone number linking found in history'),
        ),
      );
      return;
    }

    final month = item['month'];
    final name = item['employee_name'] ?? widget.employeeName;
    final net = item['net_pay'];
    final base = item['base_salary'];
    final bonus = item['bonuses'];
    final deduct = item['deductions'];

    final message =
        '''
*Payslip - Popo Baking Accessories*
📅 Month: $month
👤 Employee: $name

💵 Base Salary: KES $base
➕ Bonuses: KES $bonus
➖ Deductions: KES $deduct
================
💰 *NET PAY: KES $net*
================
Sent via Popo App
''';

    final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              'No payment history found',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final item = _history[i];
        final date =
            DateTime.tryParse(
              item['payment_date'] ?? item['created_at'] ?? '',
            ) ??
            DateTime.now();
        final status = item['run_status'] ?? 'Unknown';
        final isPaid = status == 'Paid';
        final netPay = double.tryParse(item['net_pay'].toString()) ?? 0;

        return InkWell(
          onTap: null, // No details screen navigation
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Status Icon, Title, Date, Amount
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isPaid
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPaid ? Icons.check : Icons.history,
                        color: isPaid ? Colors.green : Colors.orange,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['month'] ?? 'Unknown Period',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Paid on ${DateFormat('MMM d, yyyy').format(date)}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'KES ${NumberFormat('#,##0').format(netPay)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isPaid
                                ? Colors.green.shade50
                                : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isPaid
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const Divider(height: 24),

                // Action Buttons Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!isPaid)
                      _buildActionButton(
                        icon: Icons.edit_outlined,
                        label: 'Edit',
                        color: Colors.grey,
                        onTap: () => _editItem(item),
                      ),
                    _buildActionButton(
                      icon: Icons.share_outlined,
                      label: 'Share',
                      color: Colors.green,
                      onTap: () => _sharePayslip(item),
                    ),
                    _buildActionButton(
                      icon: Icons.picture_as_pdf_outlined,
                      label: 'Print',
                      color: Colors.red,
                      onTap: () => _generatePdf(item),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
