import 'package:flutter/material.dart';

import 'modules/core/screens/main_layout.dart';

void main() {
  runApp(const PopoBakingApp());
}

class PopoBakingApp extends StatelessWidget {
  const PopoBakingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Popo Baking ERP',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainLayout(),
    );
  }
}
