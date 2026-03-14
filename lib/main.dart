import 'package:flutter/material.dart';
import 'pages/login_page.dart';

void main() {
  runApp(const SuperBettApp());
}

class SuperBettApp extends StatelessWidget {
  const SuperBettApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SuperBett POS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}