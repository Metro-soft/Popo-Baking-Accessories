import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:frontend/modules/core/services/api_service.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  final _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _logs = [];

  // Filters
  String? _selectedAction;
  DateTime? _startDate;
  DateTime? _endDate;

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
        startDate: _startDate?.toIso8601String(),
        endDate: _endDate?.toIso8601String(),
      );
      setState(() => _logs = logs);
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
          Padding(
            padding: const EdgeInsets.all(16.0),
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
                // Date Picker could go here
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
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
                            child: Icon(_getIconForAction(log['action'])),
                          ),
                          title: Text(
                            '${log['username'] ?? 'Unknown'} - ${log['action']}',
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat(
                                  'yyyy-MM-dd HH:mm',
                                ).format(DateTime.parse(log['created_at'])),
                              ),
                              if (log['entity_id'] != null)
                                Text('Entity ID: ${log['entity_id']}'),
                              Text(
                                'Details: $details',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
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
        return Icons.edit;
      case 'DISPATCH_UPDATED':
        return Icons.local_shipping;
      case 'USER_LOGIN':
        return Icons.login;
      default:
        return Icons.info;
    }
  }
}
