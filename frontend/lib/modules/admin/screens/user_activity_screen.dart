import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_service.dart';

class UserActivityScreen extends StatefulWidget {
  const UserActivityScreen({super.key});

  @override
  State<UserActivityScreen> createState() => _UserActivityScreenState();
}

class _UserActivityScreenState extends State<UserActivityScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _logs = [];

  // Filters
  String? _selectedAction;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await _apiService.getActivityLogs(
        action: _selectedAction,
        startDate: _dateRange?.start.toIso8601String(),
        endDate: _dateRange?.end.toIso8601String(),
      );
      if (mounted) {
        setState(() => _logs = logs);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading logs: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Activity Logs'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchLogs),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: Row(
              children: [
                DropdownButton<String>(
                  value: _selectedAction,
                  hint: const Text('Filter by Action'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Actions')),
                    DropdownMenuItem(
                      value: 'SALE_CREATED',
                      child: Text('Sale Created'),
                    ),
                    DropdownMenuItem(
                      value: 'SALE_UPDATED',
                      child: Text('Sale Updated'),
                    ),
                    DropdownMenuItem(
                      value: 'DISPATCH_UPDATED',
                      child: Text('Dispatch Updated'),
                    ),
                    DropdownMenuItem(
                      value: 'USER_LOGIN',
                      child: Text('User Login'),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedAction = val);
                    _fetchLogs();
                  },
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(_dateRange == null ? 'All Time' : 'Custom Range'),
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now(),
                      initialDateRange: _dateRange,
                    );
                    if (picked != null) {
                      setState(() => _dateRange = picked);
                      _fetchLogs();
                    }
                  },
                ),
                if (_dateRange != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() => _dateRange = null);
                      _fetchLogs();
                    },
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                ? const Center(child: Text('No activity found.'))
                : ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final details = log['details'] ?? {};
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[50],
                            child: Icon(
                              _getIconForAction(log['action']),
                              color: Colors.blue[900],
                            ),
                          ),
                          title: Text(
                            '${log['username'] ?? 'Unknown'} - ${log['action']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                DateFormat(
                                  'yyyy-MM-dd HH:mm',
                                ).format(DateTime.parse(log['created_at'])),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              if (log['entity_id'] != null &&
                                  log['entity_id'] != 'null')
                                Text('Entity ID: ${log['entity_id']}'),
                              if (details.toString() != '{}')
                                Text(
                                  'Details: $details',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForAction(String action) {
    switch (action) {
      case 'SALE_CREATED':
        return Icons.shopping_cart;
      case 'SALE_UPDATED':
        return Icons.edit_note;
      case 'DISPATCH_UPDATED':
        return Icons.local_shipping;
      case 'USER_LOGIN':
        return Icons.login;
      default:
        return Icons.info_outline;
    }
  }
}
