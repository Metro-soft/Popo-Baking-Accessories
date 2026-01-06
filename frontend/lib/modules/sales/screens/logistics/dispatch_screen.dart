import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import 'dispatch_detail_pane.dart';

class DispatchScreen extends StatefulWidget {
  const DispatchScreen({super.key});

  @override
  State<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends State<DispatchScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<dynamic> _allDispatches = [];
  List<dynamic> _filteredDispatches = [];
  Map<String, dynamic>? _selectedOrder;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDispatches();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDispatches() async {
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.getPendingDispatches();

      // Sort: Pending > Processing > Released
      data.sort((a, b) {
        final statusPriority = {'pending': 1, 'processing': 2, 'released': 3};
        int pA = statusPriority[a['dispatch_status']] ?? 4;
        int pB = statusPriority[b['dispatch_status']] ?? 4;

        // Secondary sort by ID desc
        int pCompare = pA.compareTo(pB);
        if (pCompare != 0) return pCompare;
        return (b['id'] as int).compareTo(a['id'] as int);
      });

      if (mounted) {
        setState(() {
          _allDispatches = data;
          _filteredDispatches = data;
          _isLoading = false;
          // Auto-select first if available and none selected
          if (_selectedOrder == null && _filteredDispatches.isNotEmpty) {
            _selectedOrder = _filteredDispatches.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _filterDispatches(String query) {
    if (query.isEmpty) {
      setState(() => _filteredDispatches = _allDispatches);
      return;
    }
    final lower = query.toLowerCase();
    setState(() {
      _filteredDispatches = _allDispatches.where((order) {
        final id = order['id'].toString();
        final customer = (order['customer_name'] ?? '').toLowerCase();
        return id.contains(lower) || customer.contains(lower);
      }).toList();

      // Update selection if current selection is filtered out
      if (_selectedOrder != null &&
          !_filteredDispatches.contains(_selectedOrder)) {
        _selectedOrder = _filteredDispatches.isNotEmpty
            ? _filteredDispatches.first
            : null;
      }
    });
  }

  Future<void> _updateStatus(
    int id,
    String newStatus, {
    Map<String, dynamic>? details,
  }) async {
    try {
      await _apiService.updateDispatchStatus(
        id,
        newStatus,
        deliveryDetails: details,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Status Updated')));
        await _loadDispatches(); // Reload list

        // Reselect the updated order
        final updated = _allDispatches.firstWhere(
          (o) => o['id'] == id,
          orElse: () => null,
        );
        if (updated != null) {
          setState(() => _selectedOrder = updated);
        }
      }
    } catch (e) {
      print(e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    }
  }

  // --- Dialogs ---

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'released':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Premium background
      body: Row(
        children: [
          // LEFT COLUMN: ORDER LIST (Flex 2)
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                children: [
                  // Header & Search
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Logistics & Dispatch',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Search...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 0,
                            ),
                          ),
                          onChanged: _filterDispatches,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // List Items
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            itemCount: _filteredDispatches.length,
                            itemBuilder: (context, index) {
                              final order = _filteredDispatches[index];
                              final isSelected =
                                  _selectedOrder != null &&
                                  _selectedOrder!['id'] == order['id'];
                              final status =
                                  order['dispatch_status'] ?? 'pending';

                              return Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFFFF0F2)
                                      : Colors.white, // Light highlight
                                  border: isSelected
                                      ? const Border(
                                          left: BorderSide(
                                            color: Color(0xFFA01B2D),
                                            width: 4,
                                          ),
                                        )
                                      : null,
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  title: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Order #${order['id']}',
                                        style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        _formatDate(order['created_at']),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 6),
                                      // Customer Name & Icon
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.person,
                                            size: 14,
                                            color: Colors.grey[700],
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              order['customer_name'] ?? 'Guest',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black87,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      // Address & Icon
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.location_on,
                                            size: 14,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              order['customer_address'] ??
                                                  'No Address',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 13,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // Status Badge & Item Count
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(
                                                status,
                                              ).withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              status.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: _getStatusColor(status),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '${(order['items_list'] as List?)?.length ?? 0} Items',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  onTap: () =>
                                      setState(() => _selectedOrder = order),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),

          // RIGHT COLUMN: DETAILS PANE (Flex 4)
          Expanded(
            flex: 4,
            child: _selectedOrder == null
                ? const Center(
                    child: Text(
                      'Select an order to view details',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : DispatchDetailPane(
                    key: ValueKey(_selectedOrder!['id']),
                    order: _selectedOrder!,
                    getStatusColor: _getStatusColor,
                    onUpdateStatus: _updateStatus,
                  ),
          ),
        ],
      ),
    );
  }

  /* Widget _buildDetailPane(Map<String, dynamic> order) {
    final status = order['dispatch_status'] ?? 'pending';
    final isPending = status == 'pending';
    final isReleased = status == 'released';
    final isDelivered = status == 'delivered';

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${order['id']}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${order['customer_name']} • ${order['customer_phone'] ?? 'No Phone'}',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Items Card
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Order Items',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          order['items_summary']?.replaceAll(', ', '\n') ??
                              'No items',
                          style: const TextStyle(fontSize: 16, height: 1.5),
                        ),
                      ),
                    ),

                    // Delivery Info Box (if released)
                    if (isReleased && order['delivery_details'] != null) ...[
                      const Divider(height: 32),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Colors.white,
                              child: Icon(
                                Icons.delivery_dining,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Out for Delivery',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${order['delivery_details']['driver_name']} (${order['delivery_details']['plate']})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'Via ${order['delivery_details']['method']?.toUpperCase() ?? 'UNKNOWN'} • ${order['delivery_details']['phone']}',
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showEditDialog(order),
                              tooltip: 'Edit Details',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!isDelivered) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.checklist),
                  label: const Text('Check Packing List'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  onPressed: () => _showPackingList(order),
                ),
                const SizedBox(width: 16),
              ],

              if (isPending)
                ElevatedButton(
                  onPressed: () => _updateStatus(order['id'], 'processing'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                  child: const Text('START PROCESSING'),
                ),

              if (status == 'processing')
                ElevatedButton.icon(
                  icon: const Icon(Icons.local_shipping),
                  label: const Text('DISPATCH ORDER'),
                  onPressed: () => _showDispatchDialog(order),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA01B2D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),

              if (isReleased)
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle),
                  label: const Text('MARK DELIVERED'),
                  onPressed: () => _updateStatus(order['id'], 'delivered'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  } */
}
