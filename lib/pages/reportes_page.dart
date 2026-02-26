import 'package:flutter/material.dart';
import '../helpers.dart';

class ReportesPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String token;
  const ReportesPage({super.key, required this.userData, required this.token});
  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage> {
  DateTime _fecha    = DateTime.now();
  int      _tabIndex = 0;
  bool     _loading  = false;
  String   _error    = "";
  Map<String, dynamic> _data = {};

  String get _fechaStr =>
    "${_fecha.year}-${_fecha.month.toString().padLeft(2,'0')}-${_fecha.day.toString().padLeft(2,'0')}";

  String _fmt(dynamic n) => fmtMonto(double.tryParse(n?.toString() ?? "0") ?? 0);

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = ""; });
    try {
      final d = await apiFetch('/reportes/banca?fecha=$_fechaStr', widget.token);
      setState(() { _data = d; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _pickFecha() async {
    final p = await showDatePicker(
      context: context, initialDate: _fecha,
      firstDate: DateTime(2024), lastDate: DateTime.now());
    if (p != null) { setState(() => _fecha = p); _cargar(); }
  }

  // ── Resumen ──
  Widget _resumen() {
    final r       = (_data['resumen'] as Map?) ?? {};
    final venta   = double.tryParse(r['total_venta']?.toString()    ?? "0") ?? 0;
    final comis   = double.tryParse(r['total_comision']?.toString() ?? "0") ?? 0;
    final premios = double.tryParse(r['total_premios']?.toString()  ?? "0") ?? 0;
    final result  = double.tryParse(r['resultado']?.toString()      ?? "0") ?? (venta - comis - premios);
    return SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(children: [
      _card("Resumen General", [
        _row("Total Tickets",      r['total_tickets']?.toString()    ?? "0"),
        _row("Tickets Anulados",   r['tickets_anulados']?.toString() ?? "0"),
        _row("Venta Total",        _fmt(venta)),
        _rowC("Comisión Banca",    _fmt(comis),   const Color(0xFF6F42C1)),
        _row("Premios",            "(${_fmt(premios)})"),
        _rowB("Resultado Neto",    _fmt(result),
            result >= 0 ? const Color(0xFF198754) : const Color(0xFFDC3545)),
        _row("Premios Pendientes", r['premios_pendientes']?.toString() ?? "0"),
      ]),
    ]));
  }

  // ── Por Modalidad ──
  Widget _modalidad() {
    final mods = (_data['por_modalidad'] as List?) ?? [];
    if (mods.isEmpty) return const Center(
        child: Text("Sin datos por modalidad.", style: TextStyle(color: Colors.grey)));
    const labels = {"Q": "Quiniela", "P": "Palé", "T": "Tripleta", "SP": "Super Palé"};
    double tV = 0, tC = 0;
    for (final m in mods) {
      tV += double.tryParse(m['monto_total']?.toString()    ?? "0") ?? 0;
      tC += double.tryParse(m['comision_total']?.toString() ?? "0") ?? 0;
    }
    final tP = double.tryParse(_data['resumen']?['total_premios']?.toString() ?? "0") ?? 0;
    final tR = tV - tC - tP;
    return SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(children: [
      ...mods.map((m) {
        final v   = double.tryParse(m['monto_total']?.toString()    ?? "0") ?? 0;
        final c   = double.tryParse(m['comision_total']?.toString() ?? "0") ?? 0;
        final pct = double.tryParse(m['comision_pct']?.toString()   ?? "0") ?? 0;
        return _card(labels[m['modalidad']] ?? m['modalidad']?.toString() ?? "", [
          _row("Tickets",     m['tickets']?.toString() ?? "0"),
          _rowC("% Comisión", "${pct.toStringAsFixed(1)}%", const Color(0xFF6F42C1)),
          _row("Venta",       _fmt(v)),
          _rowC("Comisión",   _fmt(c), const Color(0xFF6F42C1)),
        ]);
      }),
      _card("RESULTADO", [
        _row("Venta Bruta", _fmt(tV)),
        _rowC("Comisión",   "(${_fmt(tC)})", const Color(0xFF6F42C1)),
        _row("Premios",     "(${_fmt(tP)})"),
        _rowB("Resultado Neto", _fmt(tR),
            tR >= 0 ? const Color(0xFF198754) : const Color(0xFFDC3545)),
      ], hColor: Colors.grey.shade700),
    ]));
  }

  // ── Por Lotería ──
  Widget _loteria() {
    final lots = (_data['por_loteria'] as List?) ?? [];
    if (lots.isEmpty) return const Center(
        child: Text("Sin detalles por lotería.", style: TextStyle(color: Colors.grey)));
    double ltV = 0, ltC = 0, ltP = 0;
    for (final l in lots) {
      ltV += double.tryParse(l['monto_total']?.toString()    ?? "0") ?? 0;
      ltC += double.tryParse(l['comision_total']?.toString() ?? "0") ?? 0;
      ltP += double.tryParse(l['premios_total']?.toString()  ?? "0") ?? 0;
    }
    final ltR = ltV - ltC - ltP;
    return SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(children: [
      ...lots.map((l) {
        final v    = double.tryParse(l['monto_total']?.toString()    ?? "0") ?? 0;
        final c    = double.tryParse(l['comision_total']?.toString() ?? "0") ?? 0;
        final p    = double.tryParse(l['premios_total']?.toString()  ?? "0") ?? 0;
        final neto = v - c - p;
        return _card(l['loteria_nombre']?.toString() ?? "Lotería", [
          _row("Venta",      _fmt(v)),
          _rowC("Comisión",  "(${_fmt(c)})", const Color(0xFF6F42C1)),
          _row("Premios",    "(${_fmt(p)})"),
          _rowB("Resultado", _fmt(neto),
              neto >= 0 ? const Color(0xFF198754) : const Color(0xFFDC3545)),
        ]);
      }),
      _card("RESULTADO TOTAL", [
        _row("Venta Bruta", _fmt(ltV)),
        _rowC("Comisión",   "(${_fmt(ltC)})", const Color(0xFF6F42C1)),
        _row("Premios",     "(${_fmt(ltP)})"),
        _rowB("Resultado Neto", _fmt(ltR),
            ltR >= 0 ? const Color(0xFF198754) : const Color(0xFFDC3545)),
      ], hColor: Colors.grey.shade700),
    ]));
  }

  // ── Helpers UI ──
  Widget _card(String t, List<Widget> rows, {Color? hColor}) =>
    Card(margin: const EdgeInsets.only(bottom: 12), child: Column(children: [
      Container(width: double.infinity, padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: hColor ?? Colors.blueGrey,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
        child: Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      ...rows,
    ]));

  Widget _row(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(children: [
      Expanded(child: Text(l, style: const TextStyle(color: Colors.black54))),
      Text(v, style: const TextStyle(fontWeight: FontWeight.w500)),
    ]));

  Widget _rowC(String l, String v, Color c) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(children: [
      Expanded(child: Text(l, style: const TextStyle(color: Colors.black54))),
      Text(v, style: TextStyle(fontWeight: FontWeight.bold, color: c)),
    ]));

  Widget _rowB(String l, String v, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: Colors.grey.shade100,
        border: Border(top: BorderSide(color: Colors.grey.shade400, width: 2))),
    child: Row(children: [
      Expanded(child: Text(l, style: const TextStyle(fontWeight: FontWeight.bold))),
      Text(v, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: c)),
    ]));

  @override
  Widget build(BuildContext context) {
    final tabs = ["Resumen", "Modalidad", "Lotería"];
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reportes POS"),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.all(8), color: Colors.blueGrey.shade50,
          child: Text(
            "${widget.userData['nombre'] ?? widget.userData['username']} (${widget.userData['rol']})",
            style: const TextStyle(color: Colors.blueGrey), textAlign: TextAlign.center)),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            Expanded(child: ToggleButtons(
              isSelected: List.generate(3, (i) => i == _tabIndex),
              onPressed: (i) => setState(() => _tabIndex = i),
              borderRadius: BorderRadius.circular(8),
              selectedColor: Colors.white,
              fillColor: Colors.blueGrey,
              constraints: const BoxConstraints(minHeight: 36),
              children: tabs.map((t) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
            )),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _pickFecha,
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(
                "${_fecha.day.toString().padLeft(2,'0')}-"
                "${_fecha.month.toString().padLeft(2,'0')}-${_fecha.year}",
                style: const TextStyle(fontSize: 13)),
            ),
          ]),
        ),
        ElevatedButton(
          onPressed: _cargar,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent, foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 42),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
          child: const Text("Generar Reporte")),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
            ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
            : _data.isEmpty
              ? const Center(child: Text("Presiona Generar Reporte"))
              : IndexedStack(
                  index: _tabIndex,
                  children: [_resumen(), _modalidad(), _loteria()])),
      ]),
    );
  }
}
