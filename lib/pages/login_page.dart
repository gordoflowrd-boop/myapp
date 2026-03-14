import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'menu_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userCtrl = TextEditingController();
  final _pinCtrl  = TextEditingController();
  String _msg     = "Ingrese usuario y PIN";
  bool   _loading = false;

  @override
  void dispose() {
    _userCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final user = _userCtrl.text.trim().toLowerCase();
    final pin  = _pinCtrl.text.trim();

    if (user.isEmpty || pin.isEmpty) {
      setState(() => _msg = "Ingrese usuario y PIN");
      return;
    }

    setState(() { _loading = true; _msg = "Validando..."; });

    try {
      final prefs   = await SharedPreferences.getInstance();
      final apiBase = prefs.getString('api_base') ?? '';

      final r = await http.post(
        Uri.parse('$apiBase/api/auth/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": user, "password": pin}),
      );
      final data = jsonDecode(r.body) as Map<String, dynamic>;

      if (r.statusCode == 200) {
        await prefs.setString('token', data['token'] ?? '');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MenuPage(
              userData: data['usuario'] as Map<String, dynamic>,
              token: data['token'] as String,
            ),
          ),
        );
      } else {
        setState(() {
          _msg = data['error'] as String? ?? "Credenciales inválidas";
          _pinCtrl.clear();
        });
      }
    } catch (_) {
      setState(() => _msg = "Error de conexión");
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(children: [
            const Icon(Icons.account_balance_wallet,
                size: 80, color: Colors.blueGrey),
            const SizedBox(height: 10),
            const Text("SUPERBETT POS",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(_msg, style: TextStyle(color: Colors.blueGrey.shade600)),
            const SizedBox(height: 30),
            TextField(
              controller: _userCtrl,
              decoration: const InputDecoration(
                  labelText: "Usuario", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: "PIN", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 25),
            _loading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          foregroundColor: Colors.white),
                      child: const Text("INGRESAR"),
                    ),
                  ),
          ]),
        ),
      ),
    );
  }
}