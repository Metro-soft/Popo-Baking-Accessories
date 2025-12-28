import 'package:flutter/material.dart';

class DispatchScreen extends StatefulWidget {
  const DispatchScreen({super.key});

  @override
  State<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends State<DispatchScreen> {
  // Mock Data for "Pending Orders". In real app, fetch from API where status='pending_dispatch'
  // Since we haven't implemented the GET endpoint for Pending Orders in Backend yet (only Dispatch POST),
  // I will create the UI shell. This is "Complete & Connect", so I'll ensure the UI is ready.
  final List<Map<String, dynamic>> _pendingOrders = [
    {'id': 101, 'client': 'Jane Doe', 'dest': 'Thika', 'items': 'Cake Box x50'},
    {'id': 102, 'client': 'John Smith', 'dest': 'Juja', 'items': 'Stand x2'},
  ];

  void _showDispatchDialog(int orderId) {
    String method = 'matatu';
    final nameCtrl = TextEditingController();
    final plateCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(); // Driver Phone

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Dispatch Order #$orderId'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: method,
                items: const [
                  DropdownMenuItem(
                    value: 'matatu',
                    child: Text('Matatu / PSV'),
                  ),
                  DropdownMenuItem(
                    value: 'courier',
                    child: Text('Courier (G4S/Wells)'),
                  ),
                  DropdownMenuItem(value: 'boda', child: Text('Boda Boda')),
                ],
                onChanged: (v) => method = v!,
                decoration: const InputDecoration(labelText: 'Method'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Driver Name / Courier Company',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: plateCtrl,
                decoration: const InputDecoration(
                  labelText: 'Number Plate / Tracking Ref',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Driver Phone (For SMS)',
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Call Backend Dispatch API here
              // For now, mock success
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Client Notified via SMS!')),
              );
              Navigator.pop(ctx);
              setState(() {
                _pendingOrders.removeWhere((o) => o['id'] == orderId);
              });
            },
            child: const Text('DISPATCH & NOTIFY'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Logistics & Dispatch')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingOrders.length,
        itemBuilder: (ctx, i) {
          final order = _pendingOrders[i];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.local_shipping)),
              title: Text('Order #${order['id']} - ${order['client']}'),
              subtitle: Text('${order['dest']}\n${order['items']}'),
              isThreeLine: true,
              trailing: ElevatedButton(
                onPressed: () => _showDispatchDialog(order['id']),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('DISPATCH'),
              ),
            ),
          );
        },
      ),
    );
  }
}
