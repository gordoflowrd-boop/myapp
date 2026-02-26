import 'package:flutter/material.dart';
import '../helpers.dart';
import 'anular_ticket_page.dart';
import 'pagar_ticket_page.dart';

class ListaTicketsPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String token;
  const ListaTicketsPage({super.key, required this.userData, required this.token});
  @override
  State<ListaTicketsPage> createState() => _ListaTicketsPageState();
}

class _ListaTicketsPageState extends State<ListaTicketsPage> {
  final _searchCtrl = TextEditingController();
  List<dynamic> _tickets = [];
  bool   _loading = true;
  String _error   = "";
  DateTime _fecha = DateTime.now();
  final Map<String, List<dynamic>> _jugadasCache = {};
  final Set<String> _expandidos = {};
  int _debounceSeed = 0;

  String get _fechaStr =>
    "${_fecha.year}-${_fecha.month.toString().padLeft(2,'0')}-${_fecha.day.toString().padLeft(2,'0')}";

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar({String busq = ""}) async {
    setState(() { _loading = true; _error = ""; });
    try {
      if (busq.length >= 3) {
        final d = await apiFetch('/tickets/${busq.toUpperCase()}', widget.token);
        if (d['jugadas'] != null) {
          _jugadasCache[d['numero_ticket'].toString()] = d['jugadas'];
        }
        setState(() { _tickets = [d]; _loading = false; });
      } else {
        final d = await apiFetch('/tickets?fecha=$_fechaStr', widget.token);
        setState(() { _tickets = d['tickets'] ?? []; _loading = false; });
      }
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _pickFecha() async {
    final p = await showDatePicker(
      context: context, initialDate: _fecha,
      firstDate: DateTime(2024), lastDate: DateTime.now());
    if (p != null) {
      setState(() { _fecha = p; _expandidos.clear(); });
      _cargar();
    }
  }

  void _onSearch(String v) {
    final seed = ++_debounceSeed;
    Future.delayed(const Duration(milliseconds: 400), () {
      if (seed != _debounceSeed) return;
      if (v.length >= 3) _cargar(busq: v);
      else if (v.isEmpty) _cargar();
    });
  }

  String _fmtFecha(String? f) {
    if (f == null || f.isEmpty) return "";
    final s = f.contains("T") ? f.split("T")[0] : f;
    final p = s.split("-");
    return p.length == 3 ? "${p[2]}-${p[1]}-${p[0]}" : s;
  }

  String _fmtHora(String? h) {
    if (h == null || h.isEmpty) return "";
    final p = h.split(":");
    if (p.length < 2) return h;
    final hh = int.tryParse(p[0]) ?? 0;
    return "${hh % 12 == 0 ? 12 : hh % 12}:${p[1].padLeft(2,'0')} ${hh >= 12 ? 'PM' : 'AM'}";
  }

  Widget _badge(Map t) {
    final anulado  = t['anulado'] == true || t['anulado'] == 1;
    final ganado   = double.tryParse(t['total_ganado']?.toString()       ?? "0") ?? 0;
    final pendiente= int.tryParse(t['premios_pendientes']?.toString() ?? "0") ?? 0;
    Color bg; Color fg; String label;
    if (anulado)                           { bg = const Color(0xFFF8D7DA); fg = const Color(0xFFB02A37); label = "ANULADO"; }
    else if (ganado > 0 && pendiente == 0) { bg = const Color(0xFFD1E7DD); fg = const Color(0xFF0F5132); label = "PAGADO"; }
    else if (ganado > 0)                   { bg = const Color(0xFFFFF3CD); fg = const Color(0xFF856404); label = "GANADOR ${fmtMonto(ganado)}"; }
    else return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11)));
  }

  Widget _tarjeta(Map t) {
    final num       = t['numero_ticket']?.toString() ?? "";
    final anulado   = t['anulado'] == true || t['anulado'] == 1;
    final monto     = double.tryParse(t['total_monto']?.toString()        ?? "0") ?? 0;
    final ganado    = double.tryParse(t['total_ganado']?.toString()       ?? "0") ?? 0;
    final pendiente = int.tryParse(t['premios_pendientes']?.toString() ?? "0") ?? 0;
    final expand    = _expandidos.contains(num);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: anulado ? const Color(0xFFF5C2C7) : Colors.grey.shade300)),
      color: anulado ? const Color(0xFFFFF5F5) : Colors.white,
      child: Column(children: [
        // Cabecera
        InkWell(
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(10),
            bottom: expand ? Radius.zero : const Radius.circular(10)),
          onTap: () async {
            setState(() { expand ? _expandidos.remove(num) : _expandidos.add(num); });
            if (!_expandidos.contains(num)) return;
            if (!_jugadasCache.containsKey(num)) {
              try {
                final d = await apiFetch('/tickets/$num', widget.token);
                _jugadasCache[num] = d['jugadas'] ?? [];
              } catch (_) { _jugadasCache[num] = []; }
              setState(() {});
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: anulado ? const Color(0xFFF8D7DA) : Colors.grey.shade100,
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(10),
                bottom: expand ? Radius.zero : const Radius.circular(10))),
            child: Row(children: [
              Text(num, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15,
                  color: anulado ? const Color(0xFFB02A37) : Colors.black)),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("${_fmtFecha(t['fecha']?.toString())} ${_fmtHora(t['hora']?.toString())}",
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                if ((t['loteria'] ?? "").toString().isNotEmpty)
                  Text(t['loteria'].toString(),
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ])),
              _badge(t as Map<dynamic, dynamic>),
              const SizedBox(width: 6),
              Text(fmtMonto(monto), style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15,
                color: anulado ? const Color(0xFFB02A37) : const Color(0xFF198754),
                decoration: anulado ? TextDecoration.lineThrough : null)),
              const SizedBox(width: 4),
              Icon(expand ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.grey),
            ]),
          ),
        ),
        // Jugadas
        if (expand) ...[
          const Divider(height: 1),
          _jugadasCache.containsKey(num)
            ? Column(children: (_jugadasCache[num] ?? []).map<Widget>((j) {
                final prem = double.tryParse(j['premio']?.toString() ?? "0") ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  child: Row(children: [
                    SizedBox(width: 28, child: Text(j['modalidad']?.toString() ?? "",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D6EFD)))),
                    Expanded(child: Text(j['numeros']?.toString() ?? "",
                        style: const TextStyle(fontWeight: FontWeight.bold))),
                    Text("× ${j['cantidad']}", style: const TextStyle(color: Colors.grey)),
                    const SizedBox(width: 8),
                    Text(fmtMonto(double.tryParse(j['monto']?.toString() ?? "0") ?? 0),
                        style: const TextStyle(color: Color(0xFF198754), fontWeight: FontWeight.bold)),
                    if (prem > 0) ...[
                      const SizedBox(width: 6),
                      Text("🏆 ${fmtMonto(prem)}",
                          style: const TextStyle(color: Color(0xFFDC3545),
                              fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ]));
              }).toList())
            : const Padding(padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          const Divider(height: 1),
          // Acciones
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(children: [
              Expanded(child: ElevatedButton.icon(
                onPressed: () => snack(context, "Copiar: próximamente"),
                icon: const Icon(Icons.copy, size: 15),
                label: const Text("Copiar", style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D6EFD), foregroundColor: Colors.white))),
              if (!anulado && ganado == 0) ...[
                const SizedBox(width: 6),
                Expanded(child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => AnularTicketPage(
                        userData: {}, token: widget.token, prefill: num))),
                  icon: const Icon(Icons.cancel, size: 15),
                  label: const Text("Anular", style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC3545), foregroundColor: Colors.white))),
              ],
              if (ganado > 0 && pendiente > 0) ...[
                const SizedBox(width: 6),
                Expanded(child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => PagarTicketPage(
                        userData: {}, token: widget.token, prefill: num))),
                  icon: const Icon(Icons.attach_money, size: 15),
                  label: const Text("Pagar", style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF198754), foregroundColor: Colors.white))),
              ],
            ])),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tickets Vendidos"),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              decoration: const InputDecoration(
                hintText: "Buscar número ticket",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
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
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
            ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
            : _tickets.isEmpty
              ? const Center(child: Text("No hay tickets para esta fecha.",
                  style: TextStyle(color: Colors.grey)))
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.builder(
                    itemCount: _tickets.length,
                    itemBuilder: (_, i) => _tarjeta(_tickets[i] as Map)))),
      ]),
    );
  }
}
