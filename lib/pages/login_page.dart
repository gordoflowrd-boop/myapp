import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'menu_page.dart';
import 'setup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userCtrl = TextEditingController();
  final _pinCtrl  = TextEditingController();
  String _msg         = '';
  String _bancaNombre = '';
  bool   _loading     = false;
  bool   _configurado = false;

  @override
  void initState() {
    super.initState();
    _cargarBanca();
  }

  Future<void> _cargarBanca() async {
    final prefs = await SharedPreferences.getInstance();
    final nombre = prefs.getString('banca_nombre') ?? '';
    final codigo = prefs.getString('banca_codigo') ?? '';
    setState(() {
      _bancaNombre = nombre;
      _configurado = codigo.isNotEmpty;
    });
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _abrirSetup() async {
    final guardado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SetupPage()),
    );
    if (guardado == true) {
      _userCtrl.clear();
      _pinCtrl.clear();
      setState(() { _msg = ''; _bancaNombre = ''; _configurado = false; });
      await _cargarBanca();
    }
  }

  Future<void> _login() async {
    final user = _userCtrl.text.trim().toLowerCase();
    final pin  = _pinCtrl.text.trim();

    if (!_configurado) {
      setState(() => _msg = 'Primero configure la banca');
      return;
    }
    if (user.isEmpty || pin.isEmpty) {
      setState(() => _msg = 'Ingrese usuario y PIN');
      return;
    }

    setState(() { _loading = true; _msg = 'Validando...'; });

    try {
      final prefs   = await SharedPreferences.getInstance();
      final apiBase = prefs.getString('api_base')     ?? '';
      final codigo  = prefs.getString('banca_codigo') ?? '';
      final ip      = prefs.getString('ip_local')     ?? '';

      // 1. Validar config banca
      final cfgRes = await http.get(
        Uri.parse('$apiBase/api/config/$codigo?ip=${Uri.encodeComponent(ip)}'),
      ).timeout(const Duration(seconds: 15));

      if (cfgRes.statusCode != 200) {
        final err = jsonDecode(cfgRes.body);
        setState(() {
          _loading = false;
          _msg = err['error'] ?? 'Error de configuración';
        });
        return;
      }

      final config  = jsonDecode(cfgRes.body)['config'] as Map<String, dynamic>;
      final bancaId = config['id'].toString();

      await prefs.setString('banca_id',           bancaId);
      await prefs.setString('banca_nombre',         config['nombre']        ?? '');
      await prefs.setString('banca_nombre_ticket',  config['nombre_ticket'] ?? '');
      await prefs.setInt('tiempo_anulacion',
          (config['tiempo_anulacion'] as num?)?.toInt() ?? 5);

      setState(() => _bancaNombre = config['nombre'] ?? '');

      // 2. Login
      final loginRes = await http.post(
        Uri.parse('$apiBase/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': user,
          'password': pin,
          'banca_id': bancaId,
        }),
      );

      final data = jsonDecode(loginRes.body) as Map<String, dynamic>;

      if (loginRes.statusCode == 200) {
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
          _msg = data['error'] as String? ?? 'Credenciales inválidas';
          _pinCtrl.clear();
        });
      }
    } catch (_) {
      setState(() => _msg = 'Error de conexión');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // resizeToAvoidBottomInset false = no se mueve con el teclado
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),

              // Título
              const Text('SuperBett',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 36, fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E), letterSpacing: 1)),
              const SizedBox(height: 8),

              // Nombre banca o aviso de configuración
              if (!_configurado)
                const Text('Debe configurar la banca',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 13))
              else if (_bancaNombre.isNotEmpty)
                Text(_bancaNombre,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15,
                      color: Colors.blueGrey.shade600,
                      fontWeight: FontWeight.bold)),

              const SizedBox(height: 32),

              // Mensaje
              SizedBox(
                height: 40,
                child: _msg.isNotEmpty
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _msg == 'Validando...'
                              ? Colors.blue.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _msg == 'Validando...'
                                ? Colors.blue.shade200 : Colors.red.shade200),
                        ),
                        child: Text(_msg,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13,
                              color: _msg == 'Validando...'
                                  ? Colors.blue.shade700
                                  : Colors.red.shade700)),
                      )
                    : const SizedBox.shrink(),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _userCtrl,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Usuario',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                onSubmitted: (_) => _login(),
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      child: const Text('INGRESAR'),
                    ),

              const SizedBox(height: 12),

              // Botón configurar
              TextButton.icon(
                onPressed: _abrirSetup,
                icon: const Icon(Icons.settings_outlined,
                    size: 16, color: Colors.blueGrey),
                label: const Text('Configurar',
                    style: TextStyle(color: Colors.blueGrey, fontSize: 13)),
              ),

              const Spacer(),

              // Versión abajo fija
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('v1.0.0',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
