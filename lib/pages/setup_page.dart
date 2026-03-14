import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});
  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _dominioCtrl = TextEditingController();
  final _codigoCtrl  = TextEditingController();
  final _ipCtrl      = TextEditingController();

  bool   _cargando    = false;
  bool   _exito       = false;
  String _error       = '';
  String _bancaNombre = '';

  @override
  void dispose() {
    _dominioCtrl.dispose();
    _codigoCtrl.dispose();
    _ipCtrl.dispose();
    super.dispose();
  }

  Future<void> _conectar() async {
    final dominio = _dominioCtrl.text.trim().replaceAll(RegExp(r'/$'), '');
    final codigo  = _codigoCtrl.text.trim().toUpperCase();
    final ip      = _ipCtrl.text.trim();

    if (dominio.isEmpty || codigo.isEmpty || ip.isEmpty) {
      setState(() => _error = 'Todos los campos son requeridos');
      return;
    }
    if (!dominio.startsWith('http')) {
      setState(() => _error = 'El dominio debe comenzar con https://');
      return;
    }

    setState(() { _cargando = true; _error = ''; _exito = false; });

    try {
      final url = Uri.parse('$dominio/api/config/$codigo?ip=${Uri.encodeComponent(ip)}');
      final r   = await http.get(url).timeout(const Duration(seconds: 8));
      final data = jsonDecode(r.body);

      if (r.statusCode == 200) {
        final config = data['config'] as Map<String, dynamic>;
        final prefs  = await SharedPreferences.getInstance();

        await prefs.setString('api_base',           dominio);
        await prefs.setString('banca_id',            config['id']            ?? '');
        await prefs.setString('banca_codigo',         config['codigo']        ?? '');
        await prefs.setString('banca_nombre',         config['nombre']        ?? '');
        await prefs.setString('banca_nombre_ticket',  config['nombre_ticket'] ?? '');
        await prefs.setString('ip_local',             ip);
        await prefs.setInt('tiempo_anulacion',
            (config['tiempo_anulacion'] as num?)?.toInt() ?? 5);

        if (config['limite_q']  != null) await prefs.setDouble('limite_q',  (config['limite_q']  as num).toDouble());
        if (config['limite_p']  != null) await prefs.setDouble('limite_p',  (config['limite_p']  as num).toDouble());
        if (config['limite_t']  != null) await prefs.setDouble('limite_t',  (config['limite_t']  as num).toDouble());
        if (config['limite_sp'] != null) await prefs.setDouble('limite_sp', (config['limite_sp'] as num).toDouble());

        setState(() {
          _cargando    = false;
          _exito       = true;
          _bancaNombre = config['nombre'] ?? '';
        });

        // Navegar al login después de 1.2 segundos
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        }

      } else {
        setState(() {
          _cargando = false;
          _error    = data['error'] ?? 'Error (${r.statusCode})';
        });
      }
    } on Exception catch (e) {
      setState(() {
        _cargando = false;
        _error    = 'No se pudo conectar: ${e.toString().replaceAll('Exception: ', '')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F5F5),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.casino_outlined, size: 64, color: Color(0xFF1A237E)),
              const SizedBox(height: 8),
              const Text('SuperBett POS',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E))),
              const SizedBox(height: 4),
              const Text('Configuración inicial',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 32),

              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [

                      TextField(
                        controller: _dominioCtrl,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Dominio del servidor',
                          hintText:  'https://micliente.railway.app',
                          prefixIcon: Icon(Icons.language),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _codigoCtrl,
                        autocorrect: false,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                          LengthLimitingTextInputFormatter(10),
                        ],
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Código de banca',
                          hintText:  'Ej: 01',
                          prefixIcon: Icon(Icons.store_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _ipCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        onSubmitted: (_) => _conectar(),
                        decoration: const InputDecoration(
                          labelText: 'IP de esta banca',
                          hintText:  'Ej: 192.168.1.10',
                          prefixIcon: Icon(Icons.router_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(children: [
                          Icon(Icons.info_outline, size: 16,
                              color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            'El código y la IP deben coincidir '
                            'con los configurados en el panel admin.',
                            style: TextStyle(fontSize: 12,
                                color: Colors.blue.shade800),
                          )),
                        ]),
                      ),

                      // Error
                      if (_error.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(children: [
                            Icon(Icons.error_outline,
                                color: Colors.red.shade700, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error,
                                style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13))),
                          ]),
                        ),
                      ],

                      // Éxito
                      if (_exito) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Row(children: [
                            const Icon(Icons.check_circle,
                                color: Colors.green, size: 22),
                            const SizedBox(width: 10),
                            Expanded(child: Text(
                              '✓ Conectado a $_bancaNombre',
                              style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            )),
                          ]),
                        ),
                      ],

                      const SizedBox(height: 20),

                      ElevatedButton.icon(
                        onPressed: (_cargando || _exito) ? null : _conectar,
                        icon: _cargando
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : _exito
                                ? const Icon(Icons.check_circle)
                                : const Icon(Icons.check_circle_outline),
                        label: Text(_cargando
                            ? 'Conectando...'
                            : _exito ? 'Conectado ✓' : 'Conectar'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _exito
                                ? Colors.green
                                : const Color(0xFF1A237E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(14),
                            textStyle: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
