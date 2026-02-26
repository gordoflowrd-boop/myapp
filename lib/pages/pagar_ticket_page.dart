import 'package:flutter/material.dart';
import '../helpers.dart';

class PagarTicketPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String token;
  final String prefill;
  const PagarTicketPage({
    super.key,
    required this.userData,
    required this.token,
    this.prefill = "",
  });
  @override
  State<PagarTicketPage> createState() => _PagarTicketPageState();
}

class _PagarTicketPageState extends State<PagarTicketPage> {
  final _ctrl = TextEditingController();
  Map<String, dynamic>? _ticket;
  bool   _buscando = false;
  bool   _pagando  = false;
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

  Future<void> _pagar() async {
    if (_ticket == null) return;
    final ganado = double.tryParse(_ticket!['total_ganado']?.toString() ?? "0") ?? 0;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmar Pago"),
        content: Text(
          "¿Pagar el ticket #${_ticket!['numero_ticket']} por ${fmtMonto(ganado)}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text("Pagar")),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _pagando = true);
    try {
      await apiFetch('/tickets/${_ticket!['numero_ticket']}/pagar',
          widget.token, method: "POST");
      snack(context, "Ticket pagado correctamente ✓", bg: Colors.green);
      _buscar();
    } catch (e) {
      snack(context, e.toString(), bg: Colors.red);
    } finally {
      setState(() => _pagando = false);
    }
  }

  Widget _chip(String label, Color color) => Container(
    margin: const EdgeInsets.only(left: 6),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.4))),
    child: Text(label, style: TextStyle(
        color: color, fontWeight: FontWeight.bold, fontSize: 12)));

  @override
  Widget build(BuildContext context) {
    final anulado   = _ticket?['anulado'] == true || _ticket?['anulado'] == 1;
    final ganado    = double.tryParse(_ticket?['total_ganado']?.toString()       ?? "0") ?? 0;
    final pendiente = int.tryParse(_ticket?['premios_pendientes']?.toString() ?? "0") ?? 0;
    final puedePagar= _ticket != null && !anulado && ganado > 0 && pendiente > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Pago de Ticket"),
        backgroundColor: Colors.green.shade700,
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
              if (anulado)             _chip("ANULADO", Colors.red),
              if (ganado > 0 && pendiente > 0) _chip("GANADOR", Colors.orange),
              if (ganado > 0 && pendiente == 0) _chip("PAGADO", Colors.green),
            ]),
            const SizedBox(height: 8),
            Text("Monto: ${fmtMonto(double.tryParse(_ticket!['total_monto']?.toString() ?? "0") ?? 0)}"),
            Text("Fecha: ${_ticket!['fecha'] ?? ""} ${_ticket!['hora'] ?? ""}"),
            if (ganado > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.emoji_events, color: Colors.green),
                  const SizedBox(width: 8),
                  Text("Premio: ${fmtMonto(ganado)}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                ])),
            ],
            const SizedBox(height: 10),
            const Text("Jugadas:", style: TextStyle(fontWeight: FontWeight.bold)),
            ...(_ticket!['jugadas'] as List? ?? []).map((j) {
              final prem = double.tryParse(j['premio']?.toString() ?? "0") ?? 0;
              return Padding(
                padding: const EdgeInsets.only(left: 10, top: 4),
                child: Text(
                  "${j['modalidad']} | ${j['numeros']} | "
                  "${fmtMonto(double.tryParse(j['monto']?.toString() ?? "0") ?? 0)}"
                  "${prem > 0 ? ' → 🏆 ${fmtMonto(prem)}' : ''}",
                  style: TextStyle(
                    fontSize: 13,
                    color: prem > 0 ? Colors.green.shade700 : Colors.black)));
            }),
          ]))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: (!puedePagar || _pagando) ? null : _pagar,
            icon: _pagando
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.attach_money),
            label: Text(anulado     ? "Ticket anulado"
                : ganado == 0       ? "Sin premio"
                : pendiente == 0    ? "Ya fue pagado"
                : "Pagar ${fmtMonto(ganado)}"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700, foregroundColor: Colors.white,
              padding: const EdgeInsets.all(14),
              disabledBackgroundColor: Colors.grey.shade300),
          )),
        ],
      ])),
    );
  }
}
