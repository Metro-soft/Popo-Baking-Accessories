import 'package:flutter/material.dart';
import 'pay_actions_card.dart';
import '../screens/employee_history_screen.dart';
import '../widgets/payment_form_widget.dart';
import '../widgets/employee_form_widget.dart';

class EmployeeDetailPanel extends StatefulWidget {
  final Map<String, dynamic>? selectedEmployee;
  final bool isAddingEmployee;
  final bool isEditingEmployee;
  final Map<String, dynamic>? editingPayItem;
  final List<dynamic> departments;
  final List<dynamic> roles;
  final List<dynamic> locations;

  // Callbacks
  final VoidCallback onCancelAdd;
  final VoidCallback onCancelEdit;
  final Function(Map<String, dynamic>) onSaveEmployee;
  final Function(int) onDeleteEmployee;
  final Function(Map<String, dynamic>?) onEditEmployeeRequest;

  // Pay Item Callbacks
  final Function(Map<String, dynamic>) onEditPayItemRequest;
  final VoidCallback onCancelEditPayItem;
  final Function(double, double) onSavePayItem;

  // General
  final VoidCallback onRefresh;

  const EmployeeDetailPanel({
    super.key,
    required this.selectedEmployee,
    required this.isAddingEmployee,
    required this.isEditingEmployee,
    required this.editingPayItem,
    required this.departments,
    required this.roles,
    required this.locations,
    required this.onCancelAdd,
    required this.onCancelEdit,
    required this.onSaveEmployee,
    required this.onDeleteEmployee,
    required this.onEditEmployeeRequest,
    required this.onEditPayItemRequest,
    required this.onCancelEditPayItem,
    required this.onSavePayItem,
    required this.onRefresh,
  });

  @override
  State<EmployeeDetailPanel> createState() => _EmployeeDetailPanelState();
}

class _EmployeeDetailPanelState extends State<EmployeeDetailPanel> {
  int _historyRefreshId = 0;

  @override
  Widget build(BuildContext context) {
    // 1. Add Mode
    if (widget.isAddingEmployee) {
      return Container(
        color: Colors.grey[50],
        padding: const EdgeInsets.all(24),
        alignment: Alignment.topCenter,
        child: EmployeeFormWidget(
          departments: widget.departments,
          roles: widget.roles,
          locations: widget.locations,
          onSave: widget.onSaveEmployee,
          onCancel: widget.onCancelAdd,
        ),
      );
    }

    // 2. Empty State
    if (widget.selectedEmployee == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Select an employee to view details',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      );
    }

    // 3. Detail View with Overlays
    final emp = widget.selectedEmployee!;
    return Stack(
      children: [
        Column(
          children: [
            // Header Profile Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: const Color(0xFFA01B2D),
                    child: Text(
                      emp['name'][0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          emp['name'],
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('${emp['role']} • ${emp['department']}'),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.phone,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              emp['phone'] ?? 'No Phone',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(width: 16),
                            Icon(
                              Icons.email,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              emp['email'] ?? 'No Email',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Action Buttons
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit Employee',
                    onPressed: () => widget.onEditEmployeeRequest(emp),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Delete Employee',
                    onPressed: () => widget.onDeleteEmployee(emp['id']),
                  ),
                ],
              ),
            ),

            // Pay Actions Card
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 8,
              ), // Adjusted padding
              child: PayActionsCard(
                employeeId: emp['id'],
                employeeName: emp['name'],
                baseSalary:
                    double.tryParse(emp['base_salary'].toString()) ?? 0.0,
                paymentPreference: emp['payment_preference'] ?? 'FULL',
                fixedAdvanceAmount: double.tryParse(
                  emp['fixed_advance_amount'].toString(),
                ),
                onPaymentComplete: () {
                  widget.onRefresh();
                  if (mounted) setState(() => _historyRefreshId++);
                },
              ),
            ),

            // Payment History
            Expanded(
              child: Container(
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                      child: Text(
                        'Payment History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                    Expanded(
                      child: EmployeeHistoryList(
                        // Force rebuild when selected employee changes or edit closes
                        key: ValueKey(
                          '${emp['id']}_${widget.editingPayItem == null}_$_historyRefreshId',
                        ),
                        employeeId: emp['id'],
                        employeeName: emp['name'],
                        isEmbedded: true,
                        onEditItem: widget.onEditPayItemRequest,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Edit Employee Overlay
        if (widget.isEditingEmployee)
          Positioned.fill(
            child: Container(
              color: Colors.black12,
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.all(24),
              child: EmployeeFormWidget(
                employee: emp,
                departments: widget.departments,
                roles: widget.roles,
                locations: widget.locations,
                onSave: widget.onSaveEmployee,
                onCancel: widget.onCancelEdit,
              ),
            ),
          ),

        // Edit Pay Item Overlay
        if (widget.editingPayItem != null)
          Positioned.fill(
            child: Container(
              color: Colors.black12,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(24),
              child: PaymentFormWidget(
                item: widget.editingPayItem!,
                employeeName: emp['name'],
                onSave: widget.onSavePayItem,
                onCancel: widget.onCancelEditPayItem,
              ),
            ),
          ),
      ],
    );
  }
}
