import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_service.dart';
import 'payroll_screen.dart';
import 'bills_screen.dart';
import 'expenses_screen.dart';
import 'organization_settings_screen.dart';
import '../widgets/dashboard_calendar_widget.dart';
import '../widgets/payment_summary_card.dart';

import '../widgets/dashboard_chart.dart';
import '../widgets/recent_activity_list.dart';
import '../widgets/financial_overview_card.dart';
import '../widgets/new_bill_dialog.dart';

class PaymentsDashboardScreen extends StatefulWidget {
  const PaymentsDashboardScreen({super.key});

  @override
  State<PaymentsDashboardScreen> createState() =>
      _PaymentsDashboardScreenState();
}

class _PaymentsDashboardScreenState extends State<PaymentsDashboardScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = false;

  List<dynamic> _bills = [];
  List<DateTime> _payrollDates = [];
  List<DateTime> _billDates = [];
  List<dynamic> _recentActivity = [];
  List<dynamic> _allExpenses = [];
  // double _totalExpenses = 0; // Removed unused variable

  DateTime? _filterDate;
  DateTime _focusedMonth = DateTime.now();

  Map<String, dynamic> _financeSummary = {};
  List<dynamic> _monthlyStats = [];
  double _paidPayroll = 0;
  double _paidBills = 0;
  double _otherExpenses = 0;
  Timer? _timer;
  int _currentDay = DateTime.now().day;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    // Check every minute for date changes or data updates
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      final now = DateTime.now();
      if (now.day != _currentDay) {
        // Day changed (Midnight update)
        setState(() {
          _currentDay = now.day;
          _focusedMonth = now; // Auto-focus current month on new day
        });
      }
      // Refresh data silently
      _loadData(silent: true);
    });
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      // Parallel loading if possible, but keep simple for now
      final bills = await _api.getBills();

      try {
        final stats = await _api.getFinanceDashboardStats();
        _monthlyStats = stats['chartData'] ?? [];
        _financeSummary = stats['summary'] ?? {};
        _paidPayroll = (stats['payrollTotal'] as num?)?.toDouble() ?? 0;
      } catch (e) {
        print('Failed to load finance stats: $e');
      }

      // Existing Expenses Fetch (keep for Recent Activity list)
      try {
        final expenses = await _api.getExpenses();
        _allExpenses = expenses;
        _updateRecentActivity();

        // Use summary total if available, else fallback
        // Calculate Payroll Total directly from Expenses (Single Source of Truth)
        final now = DateTime.now();
        _paidPayroll = expenses.fold(0.0, (sum, item) {
          final date =
              DateTime.tryParse(item['date'].toString()) ?? DateTime(0);
          final type = item['type']?.toString();
          final amount = double.tryParse(item['amount'].toString()) ?? 0;

          // Logic: Must be PAYROLL type AND in current month
          if (type == 'PAYROLL' &&
              date.year == now.year &&
              date.month == now.month) {
            return sum + amount;
          }
          return sum;
        });

        // Calculate Paid Bills (from Expenses)
        _paidBills = expenses.fold(0.0, (sum, item) {
          final date =
              DateTime.tryParse(item['date'].toString()) ?? DateTime(0);
          final type = item['type']?.toString();
          final amount = double.tryParse(item['amount'].toString()) ?? 0;

          if (type == 'BILL' &&
              date.year == now.year &&
              date.month == now.month) {
            return sum + amount;
          }
          return sum;
        });

        // Calculate Other Expenses (Operational)
        // Expenses table source of truth.
        _otherExpenses = expenses.fold(0.0, (sum, item) {
          final date =
              DateTime.tryParse(item['date'].toString()) ?? DateTime(0);
          final type = item['type']?.toString();
          final amount = double.tryParse(item['amount'].toString()) ?? 0;

          if (date.year == now.year && date.month == now.month) {
            // Exclude Payroll and Bills (assuming Bills are type 'BILL' or handled via recurring_bills logic if separate)
            // Based on user request: "Any other thing that is not in the payroll or created throught the recurring bills"
            if (type != 'PAYROLL' && type != 'BILL') {
              return sum + amount;
            }
          }
          return sum;
        });

        if (_financeSummary['currentMonthTotal'] == null) {
          // Fallback sum of everything (Kept for now if needed, but unused in UI)
        }
      } catch (_) {
        _recentActivity = [];
      }

      setState(() {
        _bills = bills;
        _billDates = bills
            .map<DateTime>((b) => DateTime.parse(b['next_due_date']))
            .toList();

        _payrollDates = [DateTime.now()];

        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _updateRecentActivity() {
    if (_filterDate == null) {
      _recentActivity = _allExpenses.take(10).toList();
    } else {
      _recentActivity = _allExpenses.where((e) {
        final date = DateTime.tryParse(e['date'].toString());
        return date != null && DateUtils.isSameDay(date, _filterDate);
      }).toList();
    }
  }

  void _showExpenseDetails(dynamic item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item['description'] ?? item['name'] ?? 'Expense Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
              'Amount',
              'KES ${NumberFormat("#,##0").format(double.tryParse(item['amount'].toString()) ?? 0)}',
            ),
            _buildDetailRow(
              'Date',
              DateFormat(
                'MMM d, yyyy',
              ).format(DateTime.parse(item['date'] ?? item['created_at'])),
            ),
            const Divider(),
            _buildDetailRow('Branch', item['branch_name'] ?? 'N/A'),
            _buildDetailRow(
              'Initiated By',
              item['created_by_name'] ?? 'Unknown',
            ),
            const Divider(),
            _buildDetailRow(
              'Category',
              item['category_name'] ?? 'Uncategorized',
            ),
            if (item['payment_method'] != null)
              _buildDetailRow('Method', item['payment_method']),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _navigateTo(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    // Calculate Total Due for Bills (Unused in UI, kept logic or remove?)
    // final double totalDue = _bills.fold(0.0, (sum, bill) {
    //   return sum + (double.tryParse(bill['amount'].toString()) ?? 0);
    // });

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Expenses Dashboard',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        backgroundColor: Colors.grey[50], // Match bg
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Icon(Icons.search, color: Colors.grey),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Organization Settings',
            onPressed: () => _navigateTo(const OrganizationSettingsScreen()),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                // Restore MediaQuery usage for isDesktop to match original behavior (Screen Width)
                // LayoutBuilder constraints might be smaller due to App Sidebar
                final isDesktop = MediaQuery.of(context).size.width >= 1100;

                // For Tablet/Mobile, we can rely on constraints or keeping it simple
                // If not desktop, we check if we have enough width for side-by-side Chart/Gauge
                final isTablet = !isDesktop && constraints.maxWidth >= 700;

                if (isDesktop) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildSummaryCards(constraints, isDesktop: true),
                              const SizedBox(height: 24),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: DashboardChartWidget(
                                      monthlyData: _monthlyStats,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 1,
                                    child: FinancialOverviewCard(
                                      payrollTotal: _paidPayroll,
                                      billsTotal: _paidBills,
                                      expensesTotal: _otherExpenses,
                                      onAddBill: _showAddBillModal,
                                      onAddExpense: _showAddExpenseDialog,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              RecentActivityList(
                                activities: _recentActivity,
                                onSeeAll: () {},
                                onItemTap: _showExpenseDetails,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(width: 1, color: Colors.grey.shade200),
                      SizedBox(
                        width: 380,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24.0),
                          child: _buildSidebar(),
                        ),
                      ),
                    ],
                  );
                } else {
                  // Mobile / Tablet Layout
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildSummaryCards(constraints, isDesktop: false),
                        const SizedBox(height: 24),
                        // Chart & Overview
                        if (isTablet)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: DashboardChartWidget(
                                  monthlyData: _monthlyStats,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: FinancialOverviewCard(
                                  payrollTotal: _paidPayroll,
                                  billsTotal: _paidBills,
                                  expensesTotal: _otherExpenses,
                                  onAddBill: _showAddBillModal,
                                  onAddExpense: _showAddExpenseDialog,
                                ),
                              ),
                            ],
                          )
                        else ...[
                          DashboardChartWidget(monthlyData: _monthlyStats),
                          const SizedBox(height: 16),
                          FinancialOverviewCard(
                            payrollTotal: _paidPayroll,
                            billsTotal: _paidBills,
                            expensesTotal: _otherExpenses,
                            onAddBill: _showAddBillModal,
                            onAddExpense: _showAddExpenseDialog,
                          ),
                        ],
                        const SizedBox(height: 24),
                        RecentActivityList(
                          activities: _recentActivity,
                          onSeeAll: () {},
                          onItemTap: _showExpenseDetails,
                        ),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 24),
                        _buildSidebar(),
                      ],
                    ),
                  );
                }
              },
            ),
    );
  }

  Widget _buildSummaryCards(
    BoxConstraints constraints, {
    required bool isDesktop,
  }) {
    double totalDue = 0;
    for (var b in _bills) {
      totalDue += double.tryParse(b['amount'].toString()) ?? 0;
    }

    final payrollCard = PaymentSummaryCard(
      title: 'Payroll Status',
      icon: Icons.people_alt,
      accentColor: const Color(0xFFA01B2D),
      headerValue: 'active',
      headerLabel: 'Status',
      mainValue: 'KES ${NumberFormat.compact().format(_paidPayroll)}',
      subValue: 'Paid This Month',
      actionLabel: 'Manage',
      onTap: () => _navigateTo(const PayrollScreen()),
    );

    final billsCard = PaymentSummaryCard(
      title: 'Upcoming Bills',
      icon: Icons.receipt_long,
      accentColor: Colors.black87,
      headerValue: 'Next 7 Days',
      headerLabel: 'Timeline',
      mainValue: 'KES ${NumberFormat.compact().format(totalDue)}',
      subValue: '${_bills.length} Bills Due',
      actionLabel: 'View All',
      onTap: () => _navigateTo(const BillsScreen()),
    );

    final expenseCard = PaymentSummaryCard(
      title: 'Other Expenses',
      icon: Icons.account_balance_wallet_outlined,
      accentColor: Colors.orange.shade700,
      subValue: 'Operational & Misc',
      mainValue: 'KES ${NumberFormat("#,##0").format(_otherExpenses)}',
      headerLabel: 'Period',
      headerValue: 'This Month',
      actionLabel: 'View',
      onTap: () {
        _navigateTo(const ExpensesScreen());
      },
    );

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: payrollCard),
          const SizedBox(width: 16),
          Expanded(child: billsCard),
          const SizedBox(width: 16),
          Expanded(child: expenseCard),
        ],
      );
    }

    // Use Wrap for responsive cards
    // Calculate width to decide if we want 3, 2, or 1 per row
    final width = constraints.maxWidth;
    double itemWidth;
    if (width >= 1100) {
      // 3 items in a row (shouldn't really hit here if isDesktop logic matches)
      itemWidth = (width * 0.66 - 48 - 32) / 3;
    } else if (width >= 700) {
      // 2 items per row
      itemWidth = (width - 32 - 16) / 2;
    } else {
      // 1 item
      itemWidth = width - 32;
    }

    // clamp min width
    if (itemWidth < 250) itemWidth = width - 48; // fallback to full width

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        SizedBox(width: itemWidth, child: payrollCard),
        SizedBox(width: itemWidth, child: billsCard),
        SizedBox(width: itemWidth, child: expenseCard),
      ],
    );
  }

  // Same _buildUpcomingTasks and other helpers as before...
  Widget _buildUpcomingTasks() {
    List<Map<String, dynamic>> tasks = [];

    // 1. Convert Real Bills to Task Objects
    for (var bill in _bills) {
      if (bill['next_due_date'] == null) continue;
      final date = DateTime.parse(bill['next_due_date']);
      final amount = double.tryParse(bill['amount'].toString()) ?? 0;

      tasks.add({
        'title': 'Pay ${bill['name']}',
        'subtitle': 'Due ${DateFormat('MMM d').format(date)}',
        'type': 'Bill',
        'priority': 2,
        'date': date,
        'amount': 'KES ${NumberFormat('#,##0').format(amount)}',
        'raw_bill': bill,
      });
    }

    // 3. Filter
    if (_filterDate != null) {
      tasks = tasks
          .where((t) => DateUtils.isSameDay(t['date'], _filterDate))
          .toList();
    } else {
      tasks = tasks.where((t) {
        final d = t['date'] as DateTime;
        return d.year == _focusedMonth.year && d.month == _focusedMonth.month;
      }).toList();

      tasks.sort((a, b) {
        int p = (a['priority'] as int).compareTo(b['priority'] as int);
        if (p != 0) return p;
        return (a['date'] as DateTime).compareTo(b['date'] as DateTime);
      });
    }

    if (tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _filterDate == null
                ? 'No tasks for ${DateFormat('MMMM').format(_focusedMonth)}'
                : 'No tasks for ${DateFormat('MMM d').format(_filterDate!)}',
            style: TextStyle(color: Colors.grey.shade400),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _filterDate == null
              ? 'Upcoming Tasks (${DateFormat('MMMM').format(_focusedMonth)})'
              : 'Tasks for ${DateFormat('MMM d').format(_filterDate!)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        ...tasks.map((t) => _buildTaskItem(t)),
      ],
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task) {
    return GestureDetector(
      onTap: () => _showTaskDetails(task),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: task['type'] == 'Payroll'
                    ? Colors.red.shade50
                    : Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                task['type'] == 'Payroll' ? Icons.people : Icons.receipt,
                color: task['type'] == 'Payroll'
                    ? const Color(0xFFA01B2D)
                    : Colors.blueGrey,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task['title'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (_filterDate == null)
                    Text(
                      DateFormat('MMM d').format(task['date']),
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                ],
              ),
            ),
            Text(
              task['amount'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _showTaskDetails(Map<String, dynamic> task) {
    final isBill = task['type'] == 'Bill';
    final raw = task['raw_bill'];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                isBill ? Icons.receipt : Icons.people,
                color: isBill ? Colors.blueGrey : const Color(0xFFA01B2D),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  task['title'],
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Amount', task['amount']),
              _buildDetailRow(
                'Date',
                DateFormat('MMM d, yyyy').format(task['date']),
              ),
              if (isBill && raw != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Instructions:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        raw['payment_instructions'] ?? 'None',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Vendor: ${raw['vendor'] ?? 'Unknown'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (isBill)
              TextButton(
                onPressed: () async {
                  if (!context.mounted) return;
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Confirm Delete'),
                      content: const Text(
                        'Are you sure you want to delete this bill?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await _api.deleteBill(raw['id']);
                    if (!context.mounted) return;
                    Navigator.pop(context); // Close details
                    _loadData(); // Reload
                  }
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA01B2D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                if (isBill) {
                  _showPayBillDialog(raw);
                } else {
                  _navigateTo(const PayrollScreen());
                }
              },
              child: Text(isBill ? 'Pay Now' : 'Process Run'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showPayBillDialog(dynamic bill) {
    final amountCtrl = TextEditingController(text: bill['amount'].toString());
    String paymentMethod = 'Bank Transfer';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pay: ${bill['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: amountCtrl,
              decoration: const InputDecoration(labelText: 'Amount Paid'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: paymentMethod,
              decoration: const InputDecoration(labelText: 'Payment Method'),
              items: [
                'Cash',
                'M-Pesa',
                'Bank Transfer',
                'Cheque',
              ].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (val) => paymentMethod = val!,
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
              backgroundColor: const Color(0xFFA01B2D),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                await _api.payBill(bill['id'], {
                  'amount': double.parse(amountCtrl.text),
                  'payment_method': paymentMethod,
                  'date': DateTime.now().toIso8601String(),
                });
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!context.mounted) return;
                Navigator.pop(context); // Close details dialog
                _loadData(); // This is on State, safe to call if mounted
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bill Paid successfully!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Confirm Payment'),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DashboardCalendarWidget(
          payrollDates: _payrollDates,
          billDates: _billDates,
          onMonthChanged: (month) {
            setState(() => _focusedMonth = month);
          },
          onDateSelected: (date) {
            setState(() {
              if (_filterDate != null &&
                  DateUtils.isSameDay(_filterDate, date)) {
                _filterDate = null;
              } else {
                _filterDate = date;
                _focusedMonth = date;
              }
              _updateRecentActivity();
            });
          },
        ),
        const SizedBox(height: 24),
        _buildUpcomingTasks(),
      ],
    );
  }

  Future<void> _showAddBillModal() async {
    final result = await showDialog(
      context: context,
      builder: (ctx) => const NewBillDialog(),
    );

    if (result == true) {
      if (!mounted) return;
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bill created successfully')),
      );
    }
  }

  Future<void> _showAddExpenseDialog() async {
    // We need categories. If not loaded, load them first or show loader.
    // For simplicity, we can load them inside the dialog or pre-load.
    // Let's assume we pre-load or load on fly.
    final categories = await _api.getExpenseCategories();
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => _AddExpenseDialog(categories: categories),
    );
    _loadData(); // Refresh stats after add
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
