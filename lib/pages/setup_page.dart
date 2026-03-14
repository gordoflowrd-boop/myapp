import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});
  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _dominioCtrl = TextEditingController();
  final _codigoCtrl  = TextEditingController();
  final _ipCtrl      = TextEditingController();
  String _error = '';

  @override
  void initState() {
    super.initState();
    _cargarGuardado();
  }

  Future<void> _cargarGuardado() async {
    final prefs = await SharedPreferences.getInstance();
    _dominioCtrl.text = prefs.getString('api_base')     ?? '';
    _codigoCtrl.text  = prefs.getString('banca_codigo') ?? '';
    _ipCtrl.text      = prefs.getString('ip_local')     ?? '';
  }

  @override
  void dispose() {
    _dominioCtrl.dispose();
    _codigoCtrl.dispose();
    _ipCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
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

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base',     dominio);
    await prefs.setString('banca_codigo', codigo);
    await prefs.setString('ip_local',     ip);
    await prefs.remove('banca_id');
    await prefs.remove('banca_nombre');

    if (mounted) Navigator.pop(context, true); // retorna true = guardado
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Configuración'),
      backgroundColor: const Color(0xFF1A237E),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    backgroundColor: const Color(0xFFF5F5F5),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),

          TextField(
            controller: _dominioCtrl,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Dominio del servidor',
              hintText: 'https://micliente.railway.app',
              prefixIcon: Icon(Icons.language),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 14),

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
              hintText: 'Ej: 01',
              prefixIcon: Icon(Icons.store_outlined),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _ipCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            onSubmitted: (_) => _guardar(),
            decoration: const InputDecoration(
              labelText: 'IP de esta banca',
              hintText: 'Ej: 192.168.1.10',
              prefixIcon: Icon(Icons.router_outlined),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
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
              Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'El código y la IP deben coincidir con los configurados en el panel admin.',
                style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
              )),
            ]),
          ),

          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(_error,
                  style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold)),
            ),
          ],

          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: _guardar,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(14),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ),
  );
}
