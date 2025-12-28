import 'package:flutter/material.dart';
import 'placeholder_screen.dart';
import 'close_shift_screen.dart';
// Inventory
import '../../inventory/screens/product_list_screen.dart';
import '../../inventory/screens/receive_stock_screen.dart';
import '../../inventory/screens/stock_adjustment_screen.dart';
import '../../inventory/screens/stock_transfer_screen.dart';
// Sales
import '../../sales/screens/pos/pos_screen.dart';
import '../../sales/screens/sales/invoice_list_screen.dart';
import '../../sales/screens/logistics/dispatch_screen.dart';
// Finance
import '../../finance/screens/cash_management_screen.dart';

import '../../analytics/screens/dashboard/dashboard_screen.dart';
// I only moved admin/inventory, sales, finance.
// I did NOT move dashboard or logistics/dispatch_screen explicitly.
// Checking file listing in earlier step (946) doesn't show dashboard.
// I need to check where Dashboard and Dispatch are. They were likely left behind in `lib/screens/`.
// I should move them to `lib/modules/core/screens/` or `lib/modules/analytics` / `lib/modules/sales`.
// Dashboard -> Analytics or Core? Core.
// Dispatch -> Logistics module? Or Sales? User said Sales/Distribution.

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  // Use a string key to identify the selected screen, simplified for nested nav
  String _selectedKey = 'dashboard';

  // Cache screens? Or simplified switching.
  // We will dynamic switch based on _selectedKey
  Widget _getBody() {
    switch (_selectedKey) {
      case 'dashboard':
        return const DashboardScreen();
      case 'products':
        return const ProductListScreen();
      case 'partners':
        return const PlaceholderScreen(title: 'Partners');

      // Sales
      // Sales
      case 'sales_invoices':
        return const SalesInvoicesScreen();
      case 'sales_orders':
        return const POSScreen();
      case 'payments_in':
        return const PlaceholderScreen(title: 'Payments In');
      case 'estimates':
        return const PlaceholderScreen(title: 'Estimates / Quotations');
      case 'dispatch':
        return const DispatchScreen();

      // Purchases
      case 'purchase_bills':
        return const PlaceholderScreen(title: 'Purchase Bills');
      case 'payments_out':
        return const PlaceholderScreen(title: 'Payments Out');
      case 'purchase_orders':
        return const ReceiveStockScreen();
      case 'stock_adjustment':
        return const StockAdjustmentScreen();
      case 'stock_transfer':
        return const StockTransferScreen();
      case 'cash_management':
        return const CashManagementScreen();

      case 'expenses':
        return const PlaceholderScreen(title: 'Expenses');

      // Finance
      case 'bank_accounts':
        return const PlaceholderScreen(title: 'Bank Accounts');
      case 'cash_in_hand':
        return const CloseShiftScreen();
      case 'payroll':
        return const PlaceholderScreen(title: 'Payroll');
      case 'bills':
        return const PlaceholderScreen(title: 'Bills');

      case 'user_activity':
        return const PlaceholderScreen(title: 'User Activity');

      case 'settings':
        return const PlaceholderScreen(title: 'Settings');
      case 'backups':
        return const PlaceholderScreen(title: 'Backups / Restore');
      case 'utilities':
        return const PlaceholderScreen(title: 'Utilities');
      case 'online_store':
        return const PlaceholderScreen(title: 'My Online Store Integration');

      default:
        return const DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return Scaffold(
            body: Row(
              children: [
                // Custom Sidebar
                Container(
                  width: 280,
                  color: Colors.white,
                  child: Column(
                    children: [
                      // Header
                      Container(
                        height: 80,
                        alignment: Alignment.center,
                        color: Colors.deepPurple,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cake, color: Colors.white, size: 30),
                            SizedBox(width: 10),
                            Text(
                              'Popo Baking',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Menu
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          children: [
                            _buildMenuItem(
                              'Dashboard',
                              Icons.dashboard_outlined,
                              'dashboard',
                            ),
                            _buildMenuItem(
                              'Products',
                              Icons.inventory_2_outlined,
                              'products',
                            ),
                            _buildMenuItem(
                              'Partners',
                              Icons.group_outlined,
                              'partners',
                            ),

                            _buildExpansionMenu('Sales', Icons.sell_outlined, [
                              _buildSubMenuItem(
                                'Sales Invoices',
                                'sales_invoices',
                              ),
                              _buildSubMenuItem(
                                'Sales Orders (POS)',
                                'sales_orders',
                              ),
                              _buildSubMenuItem('Payments In', 'payments_in'),
                              _buildSubMenuItem('Estimates', 'estimates'),
                              _buildSubMenuItem('Dispatch', 'dispatch'),
                            ]),

                            _buildExpansionMenu(
                              'Purchases',
                              Icons.shopping_cart_outlined,
                              [
                                _buildSubMenuItem(
                                  'Purchase Bills',
                                  'purchase_bills',
                                ),
                                _buildSubMenuItem(
                                  'Payments Out',
                                  'payments_out',
                                ),
                                _buildSubMenuItem(
                                  'Purchase Orders',
                                  'purchase_orders',
                                ),
                                _buildSubMenuItem(
                                  'Stock Adjustment',
                                  'stock_adjustment',
                                ),
                                _buildSubMenuItem(
                                  'Stock Transfer',
                                  'stock_transfer',
                                ),
                              ],
                            ),

                            _buildMenuItem(
                              'Expenses',
                              Icons.receipt_long_outlined,
                              'expenses',
                            ),

                            _buildExpansionMenu(
                              'Finance',
                              Icons.account_balance_wallet_outlined,
                              [
                                _buildSubMenuItem(
                                  'Bank Accounts',
                                  'bank_accounts',
                                ),
                                _buildSubMenuItem(
                                  'Cash in Hand',
                                  'cash_in_hand',
                                ),
                                _buildSubMenuItem('Payroll', 'payroll'),
                                _buildSubMenuItem('Bills', 'bills'),
                              ],
                            ),

                            const Divider(),
                            _buildMenuItem(
                              'User Activity',
                              Icons.history,
                              'user_activity',
                            ),
                            _buildMenuItem(
                              'Settings',
                              Icons.settings_outlined,
                              'settings',
                            ),
                            _buildMenuItem(
                              'Backups / Restore',
                              Icons.backup_outlined,
                              'backups',
                            ),
                            _buildMenuItem(
                              'Utilities',
                              Icons.build_outlined,
                              'utilities',
                            ),
                            const Divider(),
                            _buildMenuItem(
                              'My Online Store',
                              Icons.storefront,
                              'online_store',
                            ),
                          ],
                        ),
                      ),

                      // Footer
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.grey[50],
                        alignment: Alignment.center,
                        child: const Text(
                          'Version 1.0.0',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
                // Separator
                Container(width: 1, color: Colors.grey[300]),
                // Body
                Expanded(child: _getBody()),
              ],
            ),
          );
        } else {
          // Mobile Layout (Sidebar becomes Drawer)
          return Scaffold(
            appBar: AppBar(
              title: const Text('Popo Baking ERP'),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            drawer: Drawer(
              child: Column(
                children: [
                  const UserAccountsDrawerHeader(
                    accountName: Text('Admin'),
                    accountEmail: Text('v1.0.0'),
                    decoration: BoxDecoration(color: Colors.deepPurple),
                    currentAccountPicture: Icon(
                      Icons.cake,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        _buildMenuItem(
                          'Dashboard',
                          Icons.dashboard_outlined,
                          'dashboard',
                          isMobile: true,
                        ),
                        _buildMenuItem(
                          'Products',
                          Icons.inventory_2_outlined,
                          'products',
                          isMobile: true,
                        ),
                        _buildMenuItem(
                          'Partners',
                          Icons.group_outlined,
                          'partners',
                          isMobile: true,
                        ),

                        _buildExpansionMenu('Sales', Icons.sell_outlined, [
                          _buildSubMenuItem(
                            'Sales Invoices',
                            'sales_invoices',
                            isMobile: true,
                          ),
                          _buildSubMenuItem(
                            'Sales Orders (POS)',
                            'sales_orders',
                            isMobile: true,
                          ),
                          _buildSubMenuItem(
                            'Payments In',
                            'payments_in',
                            isMobile: true,
                          ),
                          _buildSubMenuItem(
                            'Estimates',
                            'estimates',
                            isMobile: true,
                          ),
                          _buildSubMenuItem(
                            'Dispatch',
                            'dispatch',
                            isMobile: true,
                          ),
                        ]),

                        _buildExpansionMenu(
                          'Purchases',
                          Icons.shopping_cart_outlined,
                          [
                            _buildSubMenuItem(
                              'Purchase Bills',
                              'purchase_bills',
                              isMobile: true,
                            ),
                            _buildSubMenuItem(
                              'Payments Out',
                              'payments_out',
                              isMobile: true,
                            ),
                            _buildSubMenuItem(
                              'Purchase Orders',
                              'purchase_orders',
                              isMobile: true,
                            ),
                          ],
                        ),

                        _buildMenuItem(
                          'Expenses',
                          Icons.receipt_long_outlined,
                          'expenses',
                          isMobile: true,
                        ),

                        _buildExpansionMenu(
                          'Finance',
                          Icons.account_balance_wallet_outlined,
                          [
                            _buildSubMenuItem(
                              'Bank Accounts',
                              'bank_accounts',
                              isMobile: true,
                            ),
                            _buildSubMenuItem(
                              'Cash in Hand',
                              'cash_in_hand',
                              isMobile: true,
                            ),
                            _buildSubMenuItem(
                              'Payroll',
                              'payroll',
                              isMobile: true,
                            ),
                            _buildSubMenuItem('Bills', 'bills', isMobile: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            body: _getBody(),
          );
        }
      },
    );
  }

  Widget _buildMenuItem(
    String title,
    IconData icon,
    String key, {
    bool isMobile = false,
  }) {
    final isSelected = _selectedKey == key;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.deepPurple : Colors.grey[600],
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.deepPurple : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onTap: () {
        setState(() => _selectedKey = key);
        if (isMobile) Navigator.pop(context);
      },
    );
  }

  Widget _buildExpansionMenu(
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    // Check if any child is selected to auto-expand or highlight parent?
    // For now, keep simple.
    return ExpansionTile(
      leading: Icon(icon, color: Colors.grey[600]),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      childrenPadding: const EdgeInsets.only(left: 20),
      collapsedIconColor: Colors.grey,
      iconColor: Colors.deepPurple,
      children: children,
    );
  }

  Widget _buildSubMenuItem(String title, String key, {bool isMobile = false}) {
    final isSelected = _selectedKey == key;
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          color: isSelected ? Colors.deepPurple : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      dense: true,
      onTap: () {
        setState(() => _selectedKey = key);
        if (isMobile) Navigator.pop(context);
      },
      trailing: isSelected
          ? const Icon(Icons.arrow_right, color: Colors.deepPurple, size: 16)
          : null,
    );
  }
}
