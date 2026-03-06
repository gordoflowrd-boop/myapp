import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _ctrl    = TextEditingController();
  final _pinCtrl = TextEditingController();

  Map<String, dynamic>? _ticket;
  int    _tiempoLimiteMin = 0;  // 0 = sin límite
  bool   _buscando  = false;
  bool   _anulando  = false;
  String _error     = "";

  @override
  void initState() {
    super.initState();
    _cargarConfig();
    if (widget.prefill.isNotEmpty) {
      _ctrl.text = widget.prefill;
      WidgetsBinding.instance.addPostFrameCallback((_) => _buscar());
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  // ── Lee tiempo_anulacion de la configuración ──────
  Future<void> _cargarConfig() async {
    try {
      final cfg   = await apiFetch('/bancas/config', widget.token);
      final banca = cfg['banca'] as Map? ?? {};
      final t     = int.tryParse(banca['tiempo_anulacion']?.toString() ?? "0") ?? 0;
      if (mounted) setState(() => _tiempoLimiteMin = t);
    } catch (_) {}
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

  // ── Minutos transcurridos desde la emisión ────────
  int _minutosTranscurridos() {
    if (_ticket == null) return 0;
    try {
      final fecha = _ticket!['fecha']?.toString() ?? '';
      final hora  = _ticket!['hora']?.toString()  ?? '';
      if (fecha.isEmpty || hora.isEmpty) return 0;
      final dt = DateTime.parse('${fecha}T$hora');
      return DateTime.now().difference(dt).inMinutes;
    } catch (_) { return 0; }
  }

  bool get _dentroDelTiempo {
    if (_tiempoLimiteMin <= 0) return true;
    return _minutosTranscurridos() <= _tiempoLimiteMin;
  }

  // ── Flujo de anulación ────────────────────────────
  Future<void> _anular() async {
    if (_ticket == null) return;

    // Bloqueo por tiempo
    if (!_dentroDelTiempo) {
      _mostrarInfo(
        icono: Icons.timer_off_outlined, color: Colors.orange,
        titulo: "Tiempo de anulación vencido",
        mensaje: "El límite para anular es de $_tiempoLimiteMin minuto(s).\n"
                 "Transcurridos: ${_minutosTranscurridos()} min.",
      );
      return;
    }

    // Pedir PIN
    _pinCtrl.clear();
    final pinIngresado = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PinDialog(
        ctrl: _pinCtrl,
        numeroTicket: _ticket!['numero_ticket']?.toString() ?? '',
      ),
    );
    if (pinIngresado == null) return;

    // Validar PIN si el ticket tiene uno
    final pinTicket = _ticket!['pin']?.toString() ?? '';
    if (pinTicket.isNotEmpty && pinIngresado != pinTicket) {
      _mostrarInfo(
        icono: Icons.lock_outline, color: Colors.red,
        titulo: "PIN incorrecto",
        mensaje: "El PIN ingresado no coincide con el del ticket.",
      );
      return;
    }

    // Si no tiene PIN, confirmación simple
    if (pinTicket.isEmpty) {
      final ok = await showDialog<bool>(
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
      if (ok != true) return;
    }

    // Ejecutar anulación
    setState(() => _anulando = true);
    try {
      await apiFetch(
        '/tickets/${_ticket!['numero_ticket']}/anular',
        widget.token, method: "POST",
      );
      if (!mounted) return;
      snack(context, "Ticket anulado correctamente ✓", bg: Colors.green);
      _buscar();
    } catch (e) {
      if (!mounted) return;
      snack(context, e.toString(), bg: Colors.red);
    } finally {
      if (mounted) setState(() => _anulando = false);
    }
  }

  void _mostrarInfo({required IconData icono, required Color color,
                     required String titulo, required String mensaje}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(children: [
          Icon(icono, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(titulo, style: TextStyle(fontSize: 15))),
        ]),
        content: Text(mensaje),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            child: const Text("Entendido")),
        ],
      ),
    );
  }

  // ── Chip de tiempo restante ───────────────────────
  Widget _chipTiempo() {
    if (_ticket == null || _tiempoLimiteMin <= 0) return const SizedBox.shrink();
    final transcurridos = _minutosTranscurridos();
    final restantes     = _tiempoLimiteMin - transcurridos;
    final vencido       = restantes <= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: vencido ? Colors.red.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: vencido ? Colors.red.shade300 : Colors.orange.shade300)),
      child: Row(children: [
        Icon(vencido ? Icons.timer_off : Icons.timer_outlined,
            color: vencido ? Colors.red : Colors.orange, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            vencido ? "⛔ Tiempo vencido — no se puede anular"
                    : "⏱ $restantes min. restante(s) para anular",
            style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13,
              color: vencido ? Colors.red : Colors.orange.shade800)),
          Text(
            "Límite: $_tiempoLimiteMin min  •  Transcurridos: $transcurridos min",
            style: TextStyle(fontSize: 11,
                color: vencido ? Colors.red.shade400 : Colors.orange.shade600)),
        ])),
      ]),
    );
  }

  Widget _tag(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
        color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
    child: Text(label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)));

  @override
  Widget build(BuildContext context) {
    final anulado     = _ticket?['anulado'] == true || _ticket?['anulado'] == 1;
    final ganado      = double.tryParse(_ticket?['total_ganado']?.toString() ?? "0") ?? 0;
    final puedeAnular = _ticket != null && !anulado && ganado == 0 && _dentroDelTiempo;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Anular Ticket"),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [

        // ── Búsqueda ─────────────────────────────────
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

        // ── Error ─────────────────────────────────────
        if (_error.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200)),
            child: Text(_error, style: const TextStyle(color: Colors.red))),

        // ── Datos del ticket ──────────────────────────
        if (_ticket != null) ...[
          _chipTiempo(),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text("Ticket: ${_ticket!['numero_ticket']}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(width: 8),
                  if (anulado) _tag("ANULADO", Colors.red),
                  if (ganado > 0) _tag("GANADOR", Colors.green),
                ]),
                const SizedBox(height: 6),
                if ((_ticket!['loteria'] ?? '').toString().isNotEmpty)
                  Text(_ticket!['loteria'].toString(),
                      style: const TextStyle(color: Colors.blueGrey, fontSize: 13)),
                Text("Total: ${fmtMonto(double.tryParse(_ticket!['total_monto']?.toString() ?? "0") ?? 0)}"),
                Text("Fecha: ${_ticket!['fecha'] ?? ''}  ${_ticket!['hora'] ?? ''}"),
                const SizedBox(height: 10),
                const Text("Jugadas:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                ...(_ticket!['jugadas'] as List? ?? []).map((j) {
                  final monto = double.tryParse(j['monto']?.toString() ?? "0") ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: Row(children: [
                      SizedBox(width: 30, child: Text(
                        j['modalidad']?.toString() ?? '',
                        style: const TextStyle(
                          color: Color(0xFF0D6EFD), fontWeight: FontWeight.bold))),
                      Expanded(child: Text(j['numeros']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                      Text("× ${j['cantidad']}",
                          style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(width: 8),
                      Text(fmtMonto(monto),
                          style: const TextStyle(
                            color: Color(0xFF198754), fontWeight: FontWeight.bold)),
                    ]));
                }),
              ]))),
          const SizedBox(height: 16),

          // ── Botón Anular ──────────────────────────
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: (!puedeAnular || _anulando) ? null : _anular,
            icon: _anulando
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Icon(anulado || !_dentroDelTiempo ? Icons.block : Icons.cancel),
            label: Text(
              anulado           ? "Ya está anulado"
              : ganado > 0      ? "Ticket ganador — no anulable"
              : !_dentroDelTiempo ? "⛔ Tiempo vencido — no anulable"
              : "Anular Ticket"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(14),
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade600),
          )),
        ],
      ])),
    );
  }
}

// ═════════════════════════════════════════════════════
// Diálogo de PIN separado (StatefulWidget para toggle)
// ═════════════════════════════════════════════════════
class _PinDialog extends StatefulWidget {
  final TextEditingController ctrl;
  final String numeroTicket;
  const _PinDialog({required this.ctrl, required this.numeroTicket});
  @override State<_PinDialog> createState() => _PinDialogState();
}
class _PinDialogState extends State<_PinDialog> {
  bool _oculto = true;
  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    title: const Row(children: [
      Icon(Icons.lock_outline, color: Colors.red),
      SizedBox(width: 8),
      Text("Verificar PIN"),
    ]),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      Text("Ticket # ${widget.numeroTicket}",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 4),
      Text("Ingrese el PIN del ticket para confirmar la anulación.",
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      const SizedBox(height: 16),
      TextField(
        controller: widget.ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        maxLength: 8,
        obscureText: _oculto,
        style: const TextStyle(
            fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
        decoration: InputDecoration(
          hintText: "• • • •",
          counterText: "",
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true, fillColor: Colors.grey.shade50,
          suffixIcon: IconButton(
            icon: Icon(_oculto ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey),
            onPressed: () => setState(() => _oculto = !_oculto),
          ),
        ),
        onSubmitted: (_) =>
            Navigator.pop(context, widget.ctrl.text.trim()),
      ),
    ]),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, null),
        child: const Text("Cancelar")),
      ElevatedButton(
        onPressed: () => Navigator.pop(context, widget.ctrl.text.trim()),
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white),
        child: const Text("Confirmar")),
    ],
  );
}
