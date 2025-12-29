import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../core/services/api_service.dart';
import '../../reports/services/pdf_report_service.dart';

class UserActivityScreen extends StatefulWidget {
  const UserActivityScreen({super.key});

  @override
  State<UserActivityScreen> createState() => _UserActivityScreenState();
}

class _UserActivityScreenState extends State<UserActivityScreen> {
  final ApiService _apiService = ApiService();
  final PdfReportService _pdfService = PdfReportService();

  bool _isLoading = false;
  List<dynamic> _auditData = [];
  List<dynamic> _branches = [];
  int? _selectedBranchId;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
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
        _refreshData();
      }
    } catch (e) {
      debugPrint('Error loading init data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      String? start = _dateRange?.start.toIso8601String();
      String? end = _dateRange?.end.toIso8601String();

      final data = await _apiService.getAuditReport(
        branchId: _selectedBranchId,
        startDate: start,
        endDate: end,
      );

      if (mounted) setState(() => _auditData = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading activity: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportPdf() async {
    try {
      setState(() => _isLoading = true);
      String dateInfo = _dateRange != null
          ? '${DateFormat('MMM d').format(_dateRange!.start)} - ${DateFormat('MMM d').format(_dateRange!.end)}'
          : 'All Time';

      String branchName = 'All Branches';
      if (_selectedBranchId != null) {
        final b = _branches.firstWhere(
          (element) => element['id'] == _selectedBranchId,
          orElse: () => {'name': 'Unknown'},
        );
        branchName = b['name'];
      }

      final pdfData = await _pdfService.generateAuditReport(
        _auditData,
        branchName,
        dateInfo,
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfData,
        name: 'user_activity_report.pdf',
      );

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Export Error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export Failed: $e')));
      }
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'adjustment':
        return Colors.orange;
      case 'transfer_out':
        return Colors.blue;
      case 'transfer_in':
        return Colors.green;
      case 'sale':
        return Colors.purple;
      case 'receive':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Activity Logs'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshData),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export Log',
            onPressed: _exportPdf,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.black54,
                      ), // Matches OutlineInputBorder default roughly
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedBranchId,
                        hint: const Text('Filter by Branch'),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<int>(
                            value: null,
                            child: Text('All Branches'),
                          ),
                          ..._branches.map((b) {
                            return DropdownMenuItem<int>(
                              value: b['id'],
                              child: Text(b['name']),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedBranchId = val);
                          _refreshData();
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(_dateRange == null ? 'All Time' : 'Custom Check'),
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now(),
                      initialDateRange: _dateRange,
                    );
                    if (picked != null) {
                      setState(() => _dateRange = picked);
                      _refreshData();
                    }
                  },
                ),
                if (_dateRange != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() => _dateRange = null);
                      _refreshData();
                    },
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _auditData.isEmpty
                ? const Center(child: Text('No activity found.'))
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          Colors.grey[50],
                        ),
                        columns: const [
                          DataColumn(
                            label: Text(
                              'Date',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Branch',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Product',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Type',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Qty',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Reason',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                        rows: _auditData.map((item) {
                          final qty =
                              double.tryParse(item['quantity'].toString()) ?? 0;
                          final isNeg = qty < 0;
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  DateFormat(
                                    'MMM d, HH:mm',
                                  ).format(DateTime.parse(item['created_at'])),
                                ),
                              ),
                              DataCell(Text(item['branch_name'] ?? 'Unknown')),
                              DataCell(Text(item['product_name'] ?? '-')),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getTypeColor(
                                      item['type'],
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item['type'].toString().toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: _getTypeColor(item['type']),
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  item['quantity'].toString(),
                                  style: TextStyle(
                                    color: isNeg ? Colors.red : Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataCell(Text(item['reason'] ?? '')),
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
}
