import 'package:flutter/material.dart';
import 'suppliers_tab.dart';
import 'customers_tab.dart';

class PartnersScreen extends StatelessWidget {
  const PartnersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Partners Management'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.local_shipping), text: 'Suppliers'),
              Tab(icon: Icon(Icons.people), text: 'Customers'),
            ],
          ),
        ),
        body: const TabBarView(children: [SuppliersTab(), CustomersTab()]),
      ),
    );
  }
}
