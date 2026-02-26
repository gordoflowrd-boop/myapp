import 'package:flutter/material.dart';
import '../helpers.dart';

class AnularTicketPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String token;
  final String prefill;
  const AnularTicketPage({
    super.key,
    required this.userData,
    required this.token,
    this.prefill = "",
  });
  @override
  State<AnularTicketPage> createState() => _AnularTicketPageState();
}

class _AnularTicketPageState extends State<AnularTicketPage> {
  final _ctrl = TextEditingController();
  Map<String, dynamic>? _ticket;
  bool   _buscando = false;
  bool   _anulando = false;
  String _error    = "";

  @override
  void initState() {
    super.initState();
    if (widget.prefill.isNotEmpty) {
      _ctrl.text = widget.prefill;
      WidgetsBinding.instance.addPostFrameCallback((_) => _buscar());
    }
  }

  Future<void> _buscar() async {
    final num = _ctrl.text.trim().toUpperCase();
    if (num.isEmpty) return;
    setState(() { _buscando = true; _ticket = null; _error = ""; });
    try {
      final d = await apiFetch('/tickets/$num', widget.token);
      setState(() { _ticket = d; _buscando = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _buscando = false; });
    }
  }

  Future<void> _anular() async {
    if (_ticket == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmar Anulación"),
        content: Text("¿Anular el ticket #${_ticket!['numero_ticket']}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Anular")),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _anulando = true);
    try {
      await apiFetch('/tickets/${_ticket!['numero_ticket']}/anular',
          widget.token, method: "POST");
      snack(context, "Ticket anulado correctamente ✓", bg: Colors.green);
      _buscar();
    } catch (e) {
      snack(context, e.toString(), bg: Colors.red);
    } finally {
      setState(() => _anulando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final anulado    = _ticket?['anulado'] == true || _ticket?['anulado'] == 1;
    final ganado     = double.tryParse(_ticket?['total_ganado']?.toString() ?? "0") ?? 0;
    final puedeAnular= _ticket != null && !anulado && ganado == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Anular Ticket"),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        // Búsqueda
        Row(children: [
          Expanded(child: TextField(
            controller: _ctrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
                labelText: "Número de Ticket", border: OutlineInputBorder()),
            onSubmitted: (_) => _buscar(),
          )),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _buscando ? null : _buscar,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey, foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16)),
            child: _buscando
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.search),
          ),
        ]),
        const SizedBox(height: 16),

        // Error
        if (_error.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200)),
            child: Text(_error, style: const TextStyle(color: Colors.red))),

        // Info ticket
        if (_ticket != null) ...[
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text("Ticket: ${_ticket!['numero_ticket']}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 8),
              if (anulado)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text("ANULADO", style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12))),
              if (ganado > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text("GANADOR", style: TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))),
            ]),
            const SizedBox(height: 6),
            Text("Total: ${fmtMonto(double.tryParse(_ticket!['total_monto']?.toString() ?? "0") ?? 0)}"),
            Text("Fecha: ${_ticket!['fecha'] ?? ""} ${_ticket!['hora'] ?? ""}"),
            const SizedBox(height: 10),
            const Text("Jugadas:", style: TextStyle(fontWeight: FontWeight.bold)),
            ...(_ticket!['jugadas'] as List? ?? []).map((j) => Padding(
              padding: const EdgeInsets.only(left: 10, top: 4),
              child: Text(
                "${j['modalidad']} | ${j['numeros']} | Cant: ${j['cantidad']} | "
                "${fmtMonto(double.tryParse(j['monto']?.toString() ?? "0") ?? 0)}",
                style: const TextStyle(fontSize: 13)))),
          ]))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: (!puedeAnular || _anulando) ? null : _anular,
            icon: _anulando
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.cancel),
            label: Text(anulado
              ? "Ya está anulado"
              : ganado > 0 ? "Ticket ganador (no anulable)"
              : "Anular Ticket"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700, foregroundColor: Colors.white,
              padding: const EdgeInsets.all(14),
              disabledBackgroundColor: Colors.grey.shade300),
          )),
        ],
      ])),
    );
  }
}
