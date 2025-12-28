import 'package:flutter/material.dart';
import 'modules/core/screens/login_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'modules/core/screens/main_layout.dart';
import 'modules/core/services/api_service.dart';

// Brand Color
const Color kPrimaryColor = Color(0xFFA01B2D); // Deep Red from Logo

void main() {
  runApp(const PopoBakingApp());
}

class PopoBakingApp extends StatefulWidget {
  const PopoBakingApp({super.key});

  @override
  State<PopoBakingApp> createState() => _PopoBakingAppState();
}

class _PopoBakingAppState extends State<PopoBakingApp> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await _apiService.loadToken();
    setState(() => _isLoading = false);
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
      home: _isLoading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _apiService.isAuthenticated
          ? const MainLayout()
          : const LoginScreen(),
    );
  }
}
