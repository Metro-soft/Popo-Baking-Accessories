import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../core/services/api_service.dart';
import '../services/pdf_report_service.dart';

class ReportsHubScreen extends StatefulWidget {
  const ReportsHubScreen({super.key});

  @override
  State<ReportsHubScreen> createState() => _ReportsHubScreenState();
}

class _ReportsHubScreenState extends State<ReportsHubScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  // View State
  int _selectedIndex = 0; // 0: Audit, 1: Sales, 2: Valuation
  bool _isLoading = false;

  // Filters
  List<dynamic> _branches = [];
  int? _selectedBranchId;
  DateTimeRange? _dateRange;
  String _selectedDateFilter = 'All Time';

  // Data
  List<dynamic> _salesData = [];
  List<dynamic> _valuationData = [];
  List<dynamic> _lowStockData = [];
  List<dynamic> _taxData = []; // [NEW]

  final List<Map<String, dynamic>> _reportTypes = [
    {
      'title': 'Sales Performance',
      'icon': Icons.attach_money,
      'desc': 'Revenue, Orders, and Branch comparison',
    },
    {
      'title': 'Inventory Valuation',
      'icon': Icons.inventory,
      'desc': 'Current asset value of stock on hand',
    },
    {
      'title': 'Low Stock Alerts',
      'icon': Icons.warning_amber_rounded,
      'desc': 'Products below reorder level',
    },
    {
      'title': 'Tax Report', // [NEW]
      'icon': Icons.account_balance,
      'desc': 'Tax Liability and Net vs Gross Revenue',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Listen to tab changes for mobile sync
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _selectedIndex = _tabController.index);
        _refreshCurrentReport();
      }
    });
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final branches = await _apiService.getBranches();
      if (mounted) {
        setState(() {
          _branches = branches;
        });
        _refreshCurrentReport();
      }
    } catch (e) {
      debugPrint('Error loading init data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshCurrentReport() async {
    setState(() => _isLoading = true);
    try {
      String? start = _dateRange?.start.toIso8601String();
      String? end = _dateRange?.end.toIso8601String();

      switch (_selectedIndex) {
        case 0: // Sales
          final data = await _apiService.getSalesPerformanceReport(
            branchId: _selectedBranchId,
            startDate: start,
            endDate: end,
          );
          if (mounted) setState(() => _salesData = data);
          break;
        case 1: // Valuation
          final data = await _apiService.getInventoryValuation(
            branchId: _selectedBranchId,
          );
          if (mounted) setState(() => _valuationData = data);
          break;
        case 2: // Low Stock
          final data = await _apiService.getLowStockReport(
            branchId: _selectedBranchId,
          );
          if (mounted) setState(() => _lowStockData = data);
          break;
        case 3: // Tax Report [NEW]
          final data = await _apiService.getTaxReport(
            branchId: _selectedBranchId,
            startDate: start,
            endDate: end,
          );
          if (mounted) setState(() => _taxData = data);
          break;
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

  void _onReportSelected(int index) {
    setState(() {
      _selectedIndex = index;
      _tabController.animateTo(index);
    });
    _refreshCurrentReport();
  }

  void _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() {
        _dateRange = picked;
        _selectedDateFilter = 'Custom Range';
      });
      _refreshCurrentReport();
    }
  }

  void _updateDateFilter(String filter) {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);

    if (filter == 'Custom Range') {
      _pickDateRange();
      return;
    }

    setState(() {
      _selectedDateFilter = filter;
      switch (filter) {
        case 'All Time':
          _dateRange = null;
          break;
        case 'Today':
          _dateRange = DateTimeRange(start: today, end: today);
          break;
        case 'Yesterday':
          final yest = today.subtract(const Duration(days: 1));
          _dateRange = DateTimeRange(start: yest, end: yest);
          break;
        case 'This Week':
          final start = today.subtract(Duration(days: today.weekday - 1));
          _dateRange = DateTimeRange(start: start, end: today);
          break;
        case 'This Month':
          final start = DateTime(today.year, today.month, 1);
          _dateRange = DateTimeRange(start: start, end: today);
          break;
      }
    });

    if (filter != 'Custom Range') {
      _refreshCurrentReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF',
            onPressed: _exportCurrentReport,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 900) {
            return _buildDesktopLayout();
          } else {
            return _buildMobileLayout();
          }
        },
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left Column: Navigation
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Available Reports',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFA01B2D),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: _reportTypes.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final r = _reportTypes[i];
                    final isSelected = _selectedIndex == i;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFA01B2D).withValues(alpha: 0.1)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          r['icon'],
                          color: isSelected
                              ? const Color(0xFFA01B2D)
                              : Colors.grey,
                        ),
                      ),
                      title: Text(
                        r['title'],
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? const Color(0xFFA01B2D)
                              : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        r['desc'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      selected: isSelected,
                      tileColor: isSelected
                          ? const Color(0xFFA01B2D).withValues(alpha: 0.05)
                          : null,
                      onTap: () => _onReportSelected(i),
                      trailing: isSelected
                          ? const Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: Color(0xFFA01B2D),
                            )
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Right Column: Content + Filters
        Expanded(
          child: Column(
            children: [
              // Header / Filter Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      _reportTypes[_selectedIndex]['title'],
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    _buildFilters(), // Reusable Filter Row
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Container(
                        padding: const EdgeInsets.all(16),
                        child: _buildCurrentReportView(),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: Column(
            children: [
              _buildFilters(isMobile: true),
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFA01B2D),
                labelColor: const Color(0xFFA01B2D),
                unselectedLabelColor: Colors.grey,
                tabs: _reportTypes
                    .map((r) => Tab(icon: Icon(r['icon']), text: r['title']))
                    .toList(),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildSalesTab(),
                    _buildValuationTab(),
                    _buildLowStockTab(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildFilters({bool isMobile = false}) {
    // If mobile, stack them? or small row.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Branch Filter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedBranchId,
              hint: const Text('All Branches'),
              icon: const Icon(Icons.arrow_drop_down),
              underline: null,
              items: [
                const DropdownMenuItem<int>(
                  value: null,
                  child: Text('All Branches'),
                ),
                ..._branches.map(
                  (b) => DropdownMenuItem<int>(
                    value: b['id'],
                    child: Text(b['name']),
                  ),
                ),
              ],
              onChanged: (val) {
                setState(() => _selectedBranchId = val);
                _refreshCurrentReport();
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Date Filter Dropdown
        PopupMenuButton<String>(
          tooltip: 'Select Date Range',
          onSelected: _updateDateFilter,
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'All Time', child: Text('All Time')),
            const PopupMenuItem(value: 'Today', child: Text('Today')),
            const PopupMenuItem(value: 'Yesterday', child: Text('Yesterday')),
            const PopupMenuItem(value: 'This Week', child: Text('This Week')),
            const PopupMenuItem(value: 'This Month', child: Text('This Month')),
            const PopupMenuItem(
              value: 'Custom Range',
              child: Text('Custom Range...'),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
              color: Colors.white,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(_selectedDateFilter),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentReportView() {
    switch (_selectedIndex) {
      case 0:
        return _buildSalesTab();
      case 1:
        return _buildValuationTab();
      case 2:
        return _buildLowStockTab();
      case 3:
        return _buildTaxTab(); // [NEW]
      default:
        return const Center(child: Text('Select a report'));
    }
  }

  // --- REPORT VIEWS (Preserved logic, slightly retained UI) ---

  Widget _buildSalesTab() {
    if (_salesData.isEmpty) {
      return const Center(child: Text('No sales data.'));
    }

    double totalRev = 0;
    int totalOrds = 0;
    for (var i in _salesData) {
      totalRev += double.tryParse(i['total_revenue'].toString()) ?? 0;
      totalOrds += int.tryParse(i['total_orders'].toString()) ?? 0;
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
              child: _buildKpiCard(
                'Total Revenue',
                NumberFormat.currency(symbol: 'KES ').format(totalRev),
                Colors.green,
                Icons.attach_money,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildKpiCard(
                'Total Orders',
                totalOrds.toString(),
                Colors.blue,
                Icons.shopping_bag,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.builder(
            itemCount: _salesData.length,
            itemBuilder: (ctx, i) {
              final item = _salesData[i];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade50,
                    child: Text(
                      item['branch_name']?[0] ?? '?',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  title: Text(
                    item['branch_name'] ?? 'Unknown Branch',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${item['total_orders']} Orders'),
                  trailing: Text(
                    NumberFormat.currency(symbol: 'KES ').format(
                      double.tryParse(item['total_revenue'].toString()) ?? 0,
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildValuationTab() {
    if (_valuationData.isEmpty) {
      return const Center(child: Text('No valuation data.'));
    }

    double totalAsset = 0;
    for (var i in _valuationData) {
      totalAsset += double.tryParse(i['total_asset_value'].toString()) ?? 0;
    }

    return Column(
      children: [
        _buildKpiCard(
          'Total Inventory Value',
          NumberFormat.currency(symbol: 'KES ').format(totalAsset),
          Colors.amber[800]!,
          Icons.inventory_2,
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.builder(
            itemCount: _valuationData.length,
            itemBuilder: (ctx, i) {
              final item = _valuationData[i];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.store, color: Colors.amber.shade800),
                  ),
                  title: Text(
                    item['branch_name'] ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${item['unique_products']} Unique Products | ${item['total_items']} items',
                  ),
                  trailing: Text(
                    NumberFormat.currency(symbol: 'KES ').format(
                      double.tryParse(item['total_asset_value'].toString()) ??
                          0,
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLowStockTab() {
    if (_lowStockData.isEmpty) {
      return const Center(child: Text('All Stock Levels Healthy.'));
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${_lowStockData.length} Items Below Reorder Level',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                  columns: const [
                    DataColumn(
                      label: Text(
                        'Product',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'SKU',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Current Stock',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Re-Order Level',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Status',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows: _lowStockData.map((item) {
                    final current =
                        double.tryParse(item['total_quantity'].toString()) ?? 0;
                    final reorder =
                        double.tryParse(item['reorder_level'].toString()) ?? 10;
                    final isCritical = current <= (reorder * 0.5);

                    return DataRow(
                      cells: [
                        DataCell(Text(item['name'] ?? 'Unknown')),
                        DataCell(Text(item['sku'] ?? '-')),
                        DataCell(
                          Text(
                            item['total_quantity'].toString(),
                            style: TextStyle(
                              color: isCritical
                                  ? Colors.red
                                  : Colors.amber[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataCell(Text(item['reorder_level'].toString())),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isCritical
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isCritical ? 'CRITICAL' : 'LOW',
                              style: TextStyle(
                                color: isCritical
                                    ? Colors.red
                                    : Colors.amber[800],
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // [NEW] Tax Tab Builder
  Widget _buildTaxTab() {
    if (_taxData.isEmpty) {
      return const Center(child: Text('No tax data found for this period.'));
    }

    // Aggregates
    double totalTax = 0;
    double netRevenue = 0;
    double grossRevenue = 0;

    for (var i in _taxData) {
      totalTax += double.tryParse(i['total_tax'].toString()) ?? 0;
      netRevenue += double.tryParse(i['net_revenue'].toString()) ?? 0;
      grossRevenue += double.tryParse(i['total_revenue'].toString()) ?? 0;
    }

    return Column(
      children: [
        // KPI Cards
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                'Tax Collected',
                NumberFormat.currency(symbol: 'KES ').format(totalTax),
                Colors.red[700]!,
                Icons.account_balance,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildKpiCard(
                'Net Revenue',
                NumberFormat.currency(symbol: 'KES ').format(netRevenue),
                Colors.teal[700]!,
                Icons.monetization_on,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildKpiCard(
                'Gross Sales',
                NumberFormat.currency(symbol: 'KES ').format(grossRevenue),
                Colors.blue[700]!,
                Icons.bar_chart,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Detailed Table
        Expanded(
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                  columns: const [
                    DataColumn(
                      label: Text(
                        'Branch',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Transactions',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Gross Sales',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Tax Collected',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Net Sales',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows: _taxData.map((item) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            item['branch_name'] ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataCell(Text(item['total_txns']?.toString() ?? '0')),
                        DataCell(
                          Text(
                            NumberFormat.currency(symbol: 'KES ').format(
                              double.tryParse(
                                    item['total_revenue'].toString(),
                                  ) ??
                                  0,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            NumberFormat.currency(symbol: 'KES ').format(
                              double.tryParse(item['total_tax'].toString()) ??
                                  0,
                            ),
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            NumberFormat.currency(symbol: 'KES ').format(
                              double.tryParse(item['net_revenue'].toString()) ??
                                  0,
                            ),
                            style: const TextStyle(
                              color: Colors.teal,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCurrentReport() async {
    try {
      setState(() => _isLoading = true);

      final pdfService = PdfReportService();
      Uint8List pdfData;
      String fileName;

      if (_selectedIndex == 2) {
        // Low Stock
        String branchName = 'All Branches';
        if (_selectedBranchId != null) {
          final b = _branches.firstWhere(
            (element) => element['id'] == _selectedBranchId,
            orElse: () => {'name': 'Unknown'},
          );
          branchName = b['name'];
        }

        pdfData = await pdfService.generateLowStockReport(
          _lowStockData,
          branchName,
        );
        fileName = 'low_stock_report.pdf';
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export for this report type not implemented yet'),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfData,
        name: fileName,
      );

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Export Error: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export Failed: $e')));
      }
    }
  }
}
