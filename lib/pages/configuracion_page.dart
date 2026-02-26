import 'package:flutter/material.dart';
import 'login_page.dart';

class ConfiguracionPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String token;
  const ConfiguracionPage({super.key, required this.userData, required this.token});
  @override
  State<ConfiguracionPage> createState() => _ConfiguracionPageState();
}

class _ConfiguracionPageState extends State<ConfiguracionPage> {
  String _tipoSalida  = "impresora";
  String _anchoTicket = "80";
  bool   _guardado    = false;

  Widget _grupo(String label, Widget child) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 8),
      child,
      const SizedBox(height: 20),
    ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Configuración"),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          _grupo("Tipo de salida de ticket",
            DropdownButtonFormField<String>(
              value: _tipoSalida,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: "impresora", child: Text("Impresora Térmica")),
                DropdownMenuItem(value: "pdf",       child: Text("Ticket PDF")),
              ],
              onChanged: (v) { if (v != null) setState(() => _tipoSalida = v); },
            )),

          _grupo("Ancho del ticket",
            DropdownButtonFormField<String>(
              value: _anchoTicket,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: "58", child: Text("58 mm")),
                DropdownMenuItem(value: "80", child: Text("80 mm")),
              ],
              onChanged: (v) { if (v != null) setState(() => _anchoTicket = v); },
            )),

          // Mensaje de guardado animado
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _guardado ? 44 : 0,
            child: _guardado
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade300)),
                  child: const Text("✓ Configuración guardada correctamente",
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center))
              : const SizedBox()),

          const SizedBox(height: 10),

          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() => _guardado = true);
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) setState(() => _guardado = false);
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, foregroundColor: Colors.white,
                padding: const EdgeInsets.all(14)),
              child: const Text("Guardar Configuración",
                  style: TextStyle(fontSize: 16)))),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 10),

          // Info sesión
          const Text("Sesión activa",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 6),
          Text("${widget.userData['nombre'] ?? widget.userData['username'] ?? '-'}",
              style: const TextStyle(fontSize: 15)),
          Text("Rol: ${widget.userData['rol'] ?? '-'}",
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),

          SizedBox(width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pushAndRemoveUntil(context,
                MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false),
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text("Cerrar Sesión",
                  style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.all(14)))),
        ]),
      ),
    );
  }
}
