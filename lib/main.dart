import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/login_page.dart';
import 'pages/setup_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs   = await SharedPreferences.getInstance();
  final apiBase = prefs.getString('api_base') ?? '';
  runApp(SuperBettApp(setupCompleto: apiBase.isNotEmpty));
}

class SuperBettApp extends StatelessWidget {
  final bool setupCompleto;
  const SuperBettApp({super.key, required this.setupCompleto});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SuperBett POS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: setupCompleto ? const LoginPage() : const SetupPage(),
    );
  }
}