import 'dart:async';
import 'package:flutter/material.dart';
import 'modules/core/screens/login_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'modules/core/screens/main_layout.dart';
import 'modules/core/services/api_service.dart';
import 'package:provider/provider.dart';
import 'modules/sales/providers/sales_provider.dart';

// Brand Color
const Color kPrimaryColor = Color(0xFFA01B2D); // Deep Red from Logo

void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        debugPrint('Caught Framework Error: ${details.exception}');
      };

      runApp(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => SalesProvider())],
          child: const PopoBakingApp(),
        ),
      );
    },
    (error, stack) {
      debugPrint('Caught Global Async Error: $error');
    },
  );
}

class PopoBakingApp extends StatefulWidget {
  const PopoBakingApp({super.key});

  @override
  State<PopoBakingApp> createState() => _PopoBakingAppState();
}

class _PopoBakingAppState extends State<PopoBakingApp> {
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    // User requested to force login on every launch.
    // We do NOT check for existing token here.
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Popo Baking ERP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimaryColor),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: ValueListenableBuilder<bool>(
        valueListenable: _apiService.authState,
        builder: (context, isAuthenticated, _) {
          return isAuthenticated ? const MainLayout() : const LoginScreen();
        },
      ),
    );
  }
}
