import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../helpers.dart';

// ─────────────────────────────────────────────────────
// Modelos
// ─────────────────────────────────────────────────────
class Jugada {
  String modalidad;
  String numeros;
  int    cantidad;
  double monto;
  Jugada({required this.modalidad, required this.numeros,
          required this.cantidad,  required this.monto});
  Map<String,dynamic> toMap() => {
    'modalidad': modalidad, 'numeros': numeros,
    'cantidad':  cantidad,  'monto':   monto,
  };
}

class Jornada {
  final String jornadaId;
  final String loteriaId;
  final String nombre;
  const Jornada({required this.jornadaId, required this.loteriaId, required this.nombre});
}

// ═════════════════════════════════════════════════════
// VENTA PAGE
// ═════════════════════════════════════════════════════
class VentaPage extends StatefulWidget {
  final Map<String,dynamic> userData;
  final String token;
  const VentaPage({super.key, required this.userData, required this.token});
  @override State<VentaPage> createState() => _VentaPageState();
}

class _VentaPageState extends State<VentaPage> {
  final _numCtrl   = TextEditingController();
  final _cantCtrl  = TextEditingController();
  final _numFocus  = FocusNode();
  final _cantFocus = FocusNode();

  List<Jugada>  _jugadas       = [];
  List<Jornada> _todasLoterias = [];
  List<String>  _jornadasSelec = [];
  List<String>  _superPaleIds  = [];

  Map<String,double> _preciosMap  = {};
  Map<String,String> _jornadaMap  = {};
  String _bancaNombre = "";

  bool   _loading = true;
  String _msg     = "";

  @override void initState() { super.initState(); _cargarTodo(); }

  // ── Precio por lotería+modalidad ──────────────────
  double _getPrecio(String? loteriaId, String mod) =>
      _preciosMap['${loteriaId}_$mod'] ?? _preciosMap['null_$mod'] ?? 0;

  // ── Carga inicial ─────────────────────────────────
  Future<void> _cargarTodo() async {
    try {
      final cfg = await apiFetch('/bancas/config', widget.token);
      final banca = cfg['banca'] as Map? ?? {};
      _bancaNombre = banca['nombre_ticket']?.toString() ?? banca['nombre']?.toString() ?? "SuperBett";
      for (final p in (cfg['precios'] as List? ?? [])) {
        final key = p['loteria_id'] != null
            ? '${p['loteria_id']}_${p['modalidad']}'
            : 'null_${p['modalidad']}';
        _preciosMap[key] = double.tryParse(p['precio'].toString()) ?? 0;
      }
      await _cargarLoterias(inicial: true);
      setState(() => _loading = false);
    } catch (e) {
      setState(() { _loading = false; _msg = e.toString(); });
    }
  }

  Future<void> _cargarLoterias({bool inicial = false}) async {
    final res      = await apiFetch('/jornadas/abiertas', widget.token);
    final jornadas = (res['jornadas'] as List? ?? []);
    final lista    = jornadas.map((j) => Jornada(
      jornadaId: j['jornada_id'].toString(),
      loteriaId: j['loteria_id']?.toString() ?? "",
      nombre:    j['nombre'].toString(),
    )).toList();
    setState(() {
      _todasLoterias = lista;
      _jornadaMap    = {for (final j in lista) j.jornadaId: j.loteriaId};
      if (inicial && _jornadasSelec.isEmpty && lista.isNotEmpty) {
        _jornadasSelec = [lista.first.jornadaId];
      }
    });
  }

  // En modo múltiple cada jugada se vende N veces (una por lotería)
  double get _total {
    final base = _jugadas.fold(0.0, (s, j) => s + j.monto);
    final mult = _jornadasSelec.length > 1 ? _jornadasSelec.length : 1;
    return base * mult;
  }

  // ── Ordenar dígitos (palé y tripleta) ─────────────
  String _sortNum(String n) {
    if (n.length == 4) return ([n.substring(0,2), n.substring(2,4)]..sort()).join('');
    if (n.length == 6) return ([n.substring(0,2), n.substring(2,4), n.substring(4,6)]..sort()).join('');
    return n;
  }

  // ── Agregar jugada ────────────────────────────────
  void _agregar() {
    String  num  = _sortNum(_numCtrl.text.trim());
    final   cant = int.tryParse(_cantCtrl.text.trim()) ?? 0;

    if (!RegExp(r'^\d{2}$|^\d{4}$|^\d{6}$').hasMatch(num)) {
      setState(() => _msg = "Jugada inválida (2, 4 o 6 dígitos)"); return;
    }
    if (cant <= 0) { setState(() => _msg = "Cantidad inválida"); return; }

    // Super Palé solo acepta palés (4 dígitos = 2 números)
    if (_superPaleIds.isNotEmpty && num.length != 4) {
      setState(() => _msg = "Super Palé: solo Palés (4 dígitos)"); return;
    }

    final mod = _superPaleIds.isNotEmpty ? "SP"
              : num.length == 2 ? "Q" : num.length == 4 ? "P" : "T";

    final lotId  = _superPaleIds.isNotEmpty ? null
                 : (_jornadasSelec.isNotEmpty ? _jornadaMap[_jornadasSelec.first] : null);
    final precio = _getPrecio(lotId, mod);
    if (precio == 0) { setState(() => _msg = "Precio no configurado"); return; }

    final monto  = precio * cant;
    final existe = _jugadas.where((j) => j.modalidad == mod && j.numeros == num);
    setState(() {
      if (existe.isNotEmpty) {
        existe.first.cantidad += cant;
        existe.first.monto    += monto;
      } else {
        _jugadas.add(Jugada(modalidad: mod, numeros: num, cantidad: cant, monto: monto));
      }
      _msg = "";
      _numCtrl.clear();
      _cantCtrl.clear();
    });
    _numFocus.requestFocus();
  }

  // ── URL base de la API ────────────────────────────
  static const _apiBase = "https://superbett-api-production.up.railway.app/api";

  /// POST directo que SIEMPRE devuelve el body JSON,
  /// incluso cuando el servidor responde 4xx/5xx (ej. límite).
  Future<Map<String,dynamic>> _post(String path, Map<String,dynamic> body) async {
    final uri = Uri.parse('$_apiBase$path');
    final resp = await http.post(uri,
      headers: {
        'Content-Type':  'application/json',
        'Authorization': 'Bearer ${widget.token}',
      },
      body: jsonEncode(body),
    );
    // Siempre parsea el body, sin importar el status code
    try {
      return jsonDecode(resp.body) as Map<String,dynamic>;
    } catch (_) {
      return {'estado': 'error', 'mensaje': 'Respuesta inválida (${resp.statusCode})'};
    }
  }

  // ── Vender ────────────────────────────────────────
  Future<void> _vender() async {
    if (_jugadas.isEmpty) { setState(() => _msg = "Agregue jugadas"); return; }
    if (_jornadasSelec.isEmpty && _superPaleIds.isEmpty) {
      setState(() => _msg = "Seleccione lotería(s)"); return;
    }
    final maps = _jugadas.map((j) => j.toMap()).toList();
    try {
      // SUPER PALÉ
      if (_superPaleIds.isNotEmpty) {
        final res = await _post('/tickets/super-pale',
            {"jornadas": _superPaleIds, "jugadas": maps});
        if (!await _manejar(res)) return;

      // MÚLTIPLE
      } else if (_jornadasSelec.length > 1) {
        final nums = <dynamic>[];
        for (final jId in _jornadasSelec) {
          final res = await _post('/tickets',
              {"jornada_id": jId, "jugadas": maps});
          if (res['estado'] == 'limite') { _modalLimite(res['detalle']); return; }
          if (res['estado'] == 'error')  { setState(() => _msg = res['mensaje'] ?? "Error"); return; }
          nums.add(res['numero_ticket']);
        }
        await _showTicket(nums);
        _limpiar();

      // NORMAL
      } else {
        final res = await _post('/tickets',
            {"jornada_id": _jornadasSelec.first, "jugadas": maps});
        if (!await _manejar(res)) return;
      }
    } catch (e) { setState(() => _msg = "Error: $e"); }
  }

  /// retorna true si OK, false si límite o error
  Future<bool> _manejar(Map<String,dynamic> res) async {
    if (res['estado'] == 'limite') { _modalLimite(res['detalle']); return false; }
    if (res['estado'] == 'error')  { setState(() => _msg = res['mensaje'] ?? "Error"); return false; }
    final n = res['numero_ticket'];
    await _showTicket(n is List ? n : [n]);
    _limpiar();
    return true;
  }

  void _limpiar() {
    setState(() {
      _jugadas.clear(); _msg = "";
      if (_todasLoterias.isNotEmpty) _jornadasSelec = [_todasLoterias.first.jornadaId];
      _superPaleIds.clear();
    });
    _numCtrl.clear(); _cantCtrl.clear();
    _numFocus.requestFocus();
  }

  // ── Modal Límite ──────────────────────────────────
  void _modalLimite(dynamic detalle) {
    final items = (detalle as List? ?? []);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Ajuste por Límite"),
      content: SizedBox(width: double.maxFinite, child: ListView(shrinkWrap: true,
        children: items.map<Widget>((d) {
          final permitido = double.tryParse(d['permitido']?.toString() ?? "0") ?? 0;
          final num = d['numeros']?.toString() ?? d['numero']?.toString() ?? '';
          return Container(margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: permitido <= 0 ? Colors.red.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: permitido <= 0 ? Colors.red : Colors.orange)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              RichText(text: TextSpan(children: [
                TextSpan(text: "${d['modalidad']} ", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 14)),
                TextSpan(text: num, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
              ])),
              Text("Solicitado: ${d['solicitado']}", style: const TextStyle(color: Colors.grey)),
              Text(permitido <= 0 ? "⚠ Sin disponible — se eliminará"
                  : "⚠ Máximo: $permitido",
                  style: TextStyle(color: permitido <= 0 ? Colors.red : Colors.orange, fontWeight: FontWeight.bold)),
            ]));
        }).toList(),
      )),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007BFF), foregroundColor: Colors.white),
          onPressed: () {
            Navigator.pop(ctx);
            for (final d in items) {
              final permitido = double.tryParse(d['permitido']?.toString() ?? "0") ?? 0;
              final num = d['numeros']?.toString() ?? d['numero']?.toString() ?? '';
              final idx = _jugadas.indexWhere((j) => j.modalidad == d['modalidad'] && j.numeros == num);
              if (idx == -1) continue;
              if (permitido <= 0) { _jugadas.removeAt(idx); continue; }
              final j = _jugadas[idx];
              final pu = j.monto / j.cantidad;
              j.cantidad = permitido.toInt();
              j.monto    = double.parse((pu * permitido).toStringAsFixed(2));
            }
            setState(() {});
          }, child: const Text("Actualizar")),
      ],
    ));
  }

  // ── Mostrar Ticket ────────────────────────────────
  Future<void> _showTicket(List numeros) async {
    try {
      final tickets = <Map<String,dynamic>>[];
      for (final n in numeros) {
        final t = await apiFetch('/tickets/$n', widget.token);
        tickets.add(t);
      }
      if (!mounted) return;
      await showDialog(context: context, barrierDismissible: false,
        builder: (_) => _TicketDialog(
          tickets: tickets,
          banca: _bancaNombre,
          onReusar: (jugadas) {
            // Agrega las jugadas del ticket a la lista actual para re-vender
            setState(() {
              for (final j in jugadas) {
                final lotId = _superPaleIds.isNotEmpty ? null
                    : (_jornadasSelec.isNotEmpty ? _jornadaMap[_jornadasSelec.first] : null);
                final precio = _getPrecio(lotId, j.modalidad);
                final monto  = precio > 0 ? precio * j.cantidad : j.monto;
                final existe = _jugadas.where(
                    (x) => x.modalidad == j.modalidad && x.numeros == j.numeros);
                if (existe.isNotEmpty) {
                  existe.first.cantidad += j.cantidad;
                  existe.first.monto    += monto;
                } else {
                  _jugadas.add(Jugada(
                    modalidad: j.modalidad,
                    numeros:   j.numeros,
                    cantidad:  j.cantidad,
                    monto:     monto,
                  ));
                }
              }
              _msg = "Jugadas cargadas ✓ — Edite y presione Vender";
            });
          },
        ));
    } catch (e) { setState(() => _msg = "Error ticket: $e"); }
  }

  // ── Abrir modal Múltiple ──────────────────────────
  void _abrirMultiple() async {
    final sel = await showDialog<List<String>>(context: context,
      builder: (_) => _SelectorDialog(loterias: _todasLoterias,
          titulo: "Seleccionar Loterías", min: 2));
    if (sel == null || sel.length < 2) {
      if (_todasLoterias.isNotEmpty) setState(() => _jornadasSelec = [_todasLoterias.first.jornadaId]);
      return;
    }
    setState(() {
      _jornadasSelec = sel; _superPaleIds.clear();
      _msg = "${sel.length} loterías seleccionadas";
      _conv('SP', 'P', _jornadaMap[sel.first]);
    });
  }

  // ── Abrir modal Super Palé ────────────────────────
  void _abrirSuperPale() async {
    final sel = await showDialog<List<String>>(context: context,
      builder: (_) => _SelectorDialog(loterias: _todasLoterias,
          titulo: "Super Palé — 2 Loterías", min: 2, max: 2));
    if (sel == null || sel.length != 2) {
      if (_todasLoterias.isNotEmpty) setState(() => _jornadasSelec = [_todasLoterias.first.jornadaId]);
      return;
    }
    setState(() {
      _superPaleIds = sel; _jornadasSelec = [];
      _msg = "Super Palé listo";
      _conv('P', 'SP', null);
    });
  }

  void _conv(String de, String a, String? lotId) {
    bool hubo = false;
    _jugadas = _jugadas.map((j) {
      if (j.modalidad != de) return j;
      final p = _getPrecio(lotId, a);
      if (p == 0) return j;
      hubo = true;
      return Jugada(modalidad: a, numeros: j.numeros, cantidad: j.cantidad, monto: p * j.cantidad);
    }).toList();
    if (hubo) _msg = "Jugadas convertidas $de → $a";
  }

  // ── Dropdown ──────────────────────────────────────
  String get _dropVal {
    if (_superPaleIds.isNotEmpty) return "SUPER_PALE";
    if (_jornadasSelec.length > 1) return "MULTI";
    return _jornadasSelec.isNotEmpty ? _jornadasSelec.first : "__none__";
  }

  // ── MIX ───────────────────────────────────────────
  void _abrirMix() async {
    final lotId = _superPaleIds.isNotEmpty ? null
        : (_jornadasSelec.isNotEmpty ? _jornadaMap[_jornadasSelec.first] : null);
    final precios = {
      'Q':  _getPrecio(lotId, 'Q'),
      'P':  _getPrecio(lotId, 'P'),
      'T':  _getPrecio(lotId, 'T'),
      'SP': _getPrecio(null,  'SP'),
    };
    final jugadas = await showDialog<List<Jugada>>(context: context,
      builder: (_) => _MixDialog(precios: precios));
    if (jugadas == null || jugadas.isEmpty) return;
    setState(() { _jugadas.addAll(jugadas); _msg = "Mix agregado ✓"; });
  }

  // ══════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Venta SuperBett"),
        backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
    body: _loading ? const Center(child: CircularProgressIndicator())
      : Column(children: [
          // Barra usuario
          Container(color: const Color(0xFF007BFF), width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: Text(
              "${widget.userData['nombre'] ?? widget.userData['username']} — $_bancaNombre",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              textAlign: TextAlign.center)),

          Padding(padding: const EdgeInsets.fromLTRB(10,6,10,0), child: Column(children: [
            // Lotería + MIX + Total
            Row(children: [
              Expanded(flex: 3, child: _buildDropdown()),
              const SizedBox(width: 5),
              GestureDetector(onTap: _abrirMix, child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: Colors.white,
                    border: Border.all(color: Colors.grey.shade400, width: 2),
                    borderRadius: BorderRadius.circular(8)),
                child: const Center(child: Text("✱",
                    style: TextStyle(color: Colors.green, fontSize: 22, fontWeight: FontWeight.bold))))),
              const SizedBox(width: 5),
              Expanded(flex: 2, child: Container(
                height: 44,
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(6)),
                child: Center(child: Text("\$${_total.toStringAsFixed(2)}",
                  style: const TextStyle(color: Colors.lightGreenAccent, fontWeight: FontWeight.bold, fontSize: 18))))),
            ]),
            const SizedBox(height: 5),
            // Número + Cantidad + Agregar
            Row(children: [
              Expanded(child: TextField(
                controller: _numCtrl, focusNode: _numFocus,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _cantFocus.requestFocus(),
                decoration: const InputDecoration(hintText: "Jugada", border: OutlineInputBorder(),
                    isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
              )),
              const SizedBox(width: 5),
              SizedBox(width: 88, child: TextField(
                controller: _cantCtrl, focusNode: _cantFocus,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _agregar(),
                decoration: const InputDecoration(hintText: "Cant", border: OutlineInputBorder(),
                    isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
              )),
              const SizedBox(width: 5),
              SizedBox(width: 90, child: ElevatedButton(
                onPressed: _agregar,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007BFF),
                    foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                child: const Text("Agregar", style: TextStyle(fontWeight: FontWeight.bold)))),
            ]),
            if (_msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4),
              child: Text(_msg, style: TextStyle(
                  color: _msg.contains("✓") || _msg.contains("listo") || _msg.contains("seleccionadas")
                      ? Colors.green : Colors.red, fontSize: 12))),
          ])),

          const SizedBox(height: 5),
          // Grid jugadas
          Expanded(child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(6)),
            child: _jugadas.isEmpty
              ? const Center(child: Text("Sin jugadas", style: TextStyle(color: Colors.grey)))
              : GridView.builder(
                  padding: const EdgeInsets.all(5),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, childAspectRatio: 1.5, crossAxisSpacing: 5, mainAxisSpacing: 5),
                  itemCount: _jugadas.length,
                  itemBuilder: (_, i) => _Globo(jugada: _jugadas[i],
                      onDelete: () => setState(() => _jugadas.removeAt(i))),
                ),
          )),

          const SizedBox(height: 5),
          Padding(padding: const EdgeInsets.fromLTRB(10,0,10,10), child: Row(children: [
            Expanded(child: _btn("Vender",   const Color(0xFF007BFF), _vender)),
            const SizedBox(width: 5),
            Expanded(child: _btn("Cancelar", const Color(0xFFF57C00), () {
              setState(() { _jugadas.clear(); _msg = "";
                if (_todasLoterias.isNotEmpty) _jornadasSelec = [_todasLoterias.first.jornadaId];
                _superPaleIds.clear(); });
              _numCtrl.clear(); _cantCtrl.clear(); _numFocus.requestFocus();
            })),
          ])),
        ]),
  );

  Widget _btn(String t, Color c, VoidCallback fn) => ElevatedButton(onPressed: fn,
    style: ElevatedButton.styleFrom(backgroundColor: c, foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12)),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)));

  Widget _buildDropdown() {
    final val = _dropVal;
    return DropdownButtonFormField<String>(
      value: val,
      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
      items: [
        if (val == "MULTI")      const DropdownMenuItem(value: "MULTI",      child: Text("Multiple...",   style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
        if (val == "SUPER_PALE") const DropdownMenuItem(value: "SUPER_PALE", child: Text("Super Palé",   style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
        if (val == "__none__")   const DropdownMenuItem(value: "__none__",   child: Text("Sin loterías", style: TextStyle(fontSize: 13))),
        ..._todasLoterias.map((l) => DropdownMenuItem(value: l.jornadaId,
            child: Text(l.nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)))),
        const DropdownMenuItem(value: "MULTI",      child: Text("Multiple...",    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
        const DropdownMenuItem(value: "SUPER_PALE", child: Text("Super Palé...", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
      ].where((i) => i != null).fold<List<DropdownMenuItem<String>>>([], (prev, e) {
        if (prev.any((x) => x.value == e.value)) return prev;
        return [...prev, e];
      }),
      onChanged: (v) {
        if (v == "MULTI")      { _abrirMultiple();  return; }
        if (v == "SUPER_PALE") { _abrirSuperPale(); return; }
        if (v != null && v != "__none__") {
          setState(() { _jornadasSelec = [v]; _superPaleIds.clear();
            _conv('SP', 'P', _jornadaMap[v]); });
        }
      },
    );
  }
}

// ═════════════════════════════════════════════════════
// GLOBO
// ═════════════════════════════════════════════════════
class _Globo extends StatelessWidget {
  final Jugada jugada; final VoidCallback onDelete;
  const _Globo({required this.jugada, required this.onDelete});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0,2))]),
    child: Stack(children: [
      Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(jugada.modalidad, style: const TextStyle(color: Color(0xFF007BFF), fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 3),
          Text(jugada.numeros, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text(" X${jugada.cantidad}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
        Text("\$${jugada.monto.toStringAsFixed(2)}", style: const TextStyle(color: Color(0xFF1A9C1A), fontWeight: FontWeight.bold, fontSize: 12)),
      ])),
      Positioned(right: 0, top: 0, child: GestureDetector(onTap: onDelete,
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
          child: const Text("✕", style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold))))),
    ]),
  );
}

// ═════════════════════════════════════════════════════
// DIALOG: SELECTOR LOTERÍAS
// ═════════════════════════════════════════════════════
class _SelectorDialog extends StatefulWidget {
  final List<Jornada> loterias;
  final String titulo;
  final int min;
  final int? max;
  const _SelectorDialog({required this.loterias, required this.titulo, this.min = 2, this.max});
  @override State<_SelectorDialog> createState() => _SelectorDialogState();
}
class _SelectorDialogState extends State<_SelectorDialog> {
  final Set<String> _sel = {};
  @override
  Widget build(BuildContext context) => Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    child: Padding(padding: const EdgeInsets.all(18), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(widget.titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Container(
        constraints: const BoxConstraints(maxHeight: 300),
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFF007BFF), width: 2),
            borderRadius: BorderRadius.circular(10), color: const Color(0xFFF0F4FF)),
        child: ListView(shrinkWrap: true, children: widget.loterias.map((l) {
          final sel = _sel.contains(l.jornadaId);
          return GestureDetector(
            onTap: () => setState(() {
              if (sel) { _sel.remove(l.jornadaId); }
              else {
                if (widget.max != null && _sel.length >= widget.max!) return;
                _sel.add(l.jornadaId);
              }
            }),
            child: AnimatedContainer(duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: sel ? const Color(0xFFE3F2FD) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: sel ? const Color(0xFF007BFF) : Colors.grey.shade300, width: sel ? 2 : 1)),
              child: Row(children: [
                Icon(sel ? Icons.check_box : Icons.check_box_outline_blank,
                    color: sel ? const Color(0xFF007BFF) : Colors.grey, size: 22),
                const SizedBox(width: 12),
                Text(l.nombre, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                    color: sel ? const Color(0xFF007BFF) : Colors.black87)),
              ]),
            ),
          );
        }).toList()),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: ElevatedButton(
          onPressed: () => Navigator.pop(context, null),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13)),
          child: const Text("Cancelar", style: TextStyle(fontWeight: FontWeight.bold)))),
        const SizedBox(width: 10),
        Expanded(child: ElevatedButton(
          onPressed: () {
            if (_sel.length < widget.min) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Seleccione al menos ${widget.min}")));
              return;
            }
            Navigator.pop(context, _sel.toList());
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007BFF), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13)),
          child: const Text("Aceptar", style: TextStyle(fontWeight: FontWeight.bold)))),
      ]),
    ])),
  );
}

// ═════════════════════════════════════════════════════
// DIALOG: MIX
// ═════════════════════════════════════════════════════
class _MixDialog extends StatefulWidget {
  final Map<String,double> precios;
  const _MixDialog({required this.precios});
  @override State<_MixDialog> createState() => _MixDialogState();
}
class _MixDialogState extends State<_MixDialog> {
  final _cs   = List.generate(6, (_) => TextEditingController());
  final _fns  = List.generate(6, (_) => FocusNode());
  final _cQ   = TextEditingController();
  final _cP   = TextEditingController();
  final _cT   = TextEditingController();
  final _cSP  = TextEditingController();
  List<Map<String,dynamic>> _items = [];
  double _total = 0;

  @override void initState() {
    super.initState();
    for (final c in [..._cs, _cQ, _cP, _cT, _cSP]) c.addListener(_calc);
  }
  @override void dispose() {
    for (final c in [..._cs, _cQ, _cP, _cT, _cSP]) c.dispose();
    for (final f in _fns) f.dispose();
    super.dispose();
  }

  // ── FIX: permite '00' como número válido ──────────
  Set<String> _nums() {
    return _cs.map((c) {
      final v = c.text.trim();
      if (v.isEmpty) return '';           // campo vacío → ignorar
      return v.padLeft(2, '0');           // '0' → '00', '5' → '05'
    }).where((n) => RegExp(r'^\d{2}$').hasMatch(n)).toSet();
  }

  Map<String, List<String>> _combinar(Set<String> n) {
    final l = n.toList();
    final Q = [...l];
    final P = <String>[], T = <String>[];
    for (int i = 0; i < l.length; i++)
      for (int j = i+1; j < l.length; j++)
        P.add(([l[i], l[j]]..sort()).join(''));
    for (int i = 0; i < l.length; i++)
      for (int j = i+1; j < l.length; j++)
        for (int k = j+1; k < l.length; k++)
          T.add(([l[i], l[j], l[k]]..sort()).join(''));
    return {'Q': Q, 'P': P, 'T': T};
  }

  void _calc() {
    final nums = _nums();
    if (nums.length < 2) { setState(() { _items = []; _total = 0; }); return; }
    final cb  = _combinar(nums);
    final cQ  = int.tryParse(_cQ.text)  ?? 0;
    final cP  = int.tryParse(_cP.text)  ?? 0;
    final cT  = int.tryParse(_cT.text)  ?? 0;
    final cSP = int.tryParse(_cSP.text) ?? 0;
    final it  = <Map<String,dynamic>>[]; double tot = 0;
    void add(String mod, List<String> ns, int c) {
      if (c <= 0 || ns.isEmpty) return;
      final pr = widget.precios[mod] ?? 0;
      for (final x in ns) { final m = pr*c; it.add({'mod':mod,'num':x,'cant':c,'monto':m}); tot+=m; }
    }
    add('Q', cb['Q']!, cQ); add('P', cb['P']!, cP);
    add('T', cb['T']!, cT); add('SP', cb['P']!, cSP);
    setState(() { _items = it; _total = tot; });
  }

  @override
  Widget build(BuildContext context) => Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    insetPadding: const EdgeInsets.all(10),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text("✱ Mezclar Números", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      // 6 inputs
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(6, (i) => SizedBox(width: 44, child: TextField(
          controller: _cs[i], focusNode: _fns[i],
          keyboardType: TextInputType.number, textAlign: TextAlign.center, maxLength: 2,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) { if (v.length == 2 && i < 5) _fns[i+1].requestFocus(); },
          decoration: InputDecoration(counterText: "", hintText: "##",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 9)),
        )))),
      const SizedBox(height: 8),
      // Cantidades
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _ci("Q",_cQ), _ci("P",_cP), _ci("T",_cT), _ci("SP",_cSP),
      ]),
      const SizedBox(height: 8),
      // Resumen
      Container(height: 190,
        decoration: BoxDecoration(border: Border.all(color: Colors.green, width: 2),
            borderRadius: BorderRadius.circular(8), color: const Color(0xFFF9FFF9)),
        child: _items.isEmpty
          ? const Center(child: Text("Ingresa 2+ números", style: TextStyle(color: Colors.grey)))
          : ListView(padding: const EdgeInsets.all(6), children: [
              ..._gruposUI(),
              if (_total > 0) Padding(padding: const EdgeInsets.only(top: 4),
                child: Text("Total: \$${_total.toStringAsFixed(2)}",
                  style: const TextStyle(color: Color(0xFF007BFF), fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right)),
            ]),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context, null),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
          child: const Text("Cancelar"))),
        const SizedBox(width: 8),
        Expanded(child: ElevatedButton(
          onPressed: _total <= 0 ? null : () => Navigator.pop(context,
            _items.map((r) => Jugada(modalidad: r['mod'], numeros: r['num'], cantidad: r['cant'], monto: r['monto'])).toList()),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12),
              disabledBackgroundColor: Colors.grey.shade300),
          child: const Text("Agregar", style: TextStyle(fontWeight: FontWeight.bold)))),
      ]),
    ])),
  );

  Widget _ci(String l, TextEditingController c) => Column(children: [
    Text(l, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    const SizedBox(height: 2),
    SizedBox(width: 60, child: TextField(controller: c,
      keyboardType: TextInputType.number, textAlign: TextAlign.center,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(hintText: "Cant",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 7)))),
  ]);

  List<Widget> _gruposUI() {
    final g = <String, List<Map>>{};
    for (final r in _items) g.putIfAbsent(r['mod'], () => []).add(r);
    const labels = {'Q':'Q — Quinielas','P':'P — Palés','T':'T — Tripletas','SP':'SP — Super Palé'};
    final ws = <Widget>[];
    for (final mod in ['Q','P','T','SP']) {
      if (!g.containsKey(mod)) continue;
      ws.add(Padding(padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(labels[mod]!, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11))));
      for (final r in g[mod]!) ws.add(Container(
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5), border: Border.all(color: const Color(0xFFD4EDDA))),
        child: Row(children: [
          SizedBox(width: 20, child: Text(r['mod'], style: const TextStyle(color: Color(0xFF007BFF), fontWeight: FontWeight.bold, fontSize: 11))),
          Expanded(child: Text(r['num'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
          Text("×${r['cant']}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(width: 6),
          Text("\$${(r['monto'] as double).toStringAsFixed(2)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
        ])));
    }
    return ws;
  }
}

// Modelo liviano para pasar jugadas de vuelta al formulario
class _JugadaReusar {
  final String modalidad;
  final String numeros;
  final int    cantidad;
  final double monto;
  const _JugadaReusar({required this.modalidad, required this.numeros,
                       required this.cantidad,  required this.monto});
}

// ═════════════════════════════════════════════════════
// DIALOG: TICKET
// ═════════════════════════════════════════════════════
class _TicketDialog extends StatelessWidget {
  final List<Map<String,dynamic>> tickets;
  final String banca;
  final void Function(List<_JugadaReusar>) onReusar;
  const _TicketDialog({
    required this.tickets,
    required this.banca,
    required this.onReusar,
  });

  // ── Orden fijo: Q → P → T → SP ────────────────────
  static const _modOrder = {'Q': 0, 'P': 1, 'T': 2, 'SP': 3};

  List _jugadasOrdenadas() {
    final p = tickets.first;
    final j = List.from(p['jugadas'] as List? ?? []);
    j.sort((a, b) => (_modOrder[a['modalidad']] ?? 9)
                   .compareTo(_modOrder[b['modalidad']] ?? 9));
    return j;
  }

  String _hora(String? h) {
    if (h == null || h.isEmpty) return '';
    final p = h.split(':');
    if (p.length < 2) return h;
    final hh = int.tryParse(p[0]) ?? 0;
    return "${hh%12==0?12:hh%12}:${p[1].padLeft(2,'0')} ${hh>=12?'PM':'AM'}";
  }

  bool get _esSP   => (tickets.first['loterias_sp'] as List?)?.isNotEmpty == true;
  bool get _esMult => tickets.length > 1;
  String get _tipo => _esSP ? 'Super Palé' : _esMult ? 'Múltiple' : 'Normal';

  // ── Texto plano para compartir/copiar ─────────────
  String _texto() {
    final p   = tickets.first;
    final j   = _jugadasOrdenadas();
    final tot = tickets.fold(0.0,(s,t)=>s+(double.tryParse(t['total_monto']?.toString()??"0")??0));
    final sb  = StringBuffer();
    sb.writeln("============================");
    sb.writeln("        SUPERBETT");
    sb.writeln("        $banca");
    sb.writeln("        ($_tipo)");
    sb.writeln("============================");
    if (!_esMult) {
      sb.writeln("Ticket # ${p['numero_ticket']}");
      if (p['pin'] != null) sb.writeln("PIN: ${p['pin']}");
    }
    if (_esSP) {
      for (final n in (p['loterias_sp'] as List<dynamic>? ?? [])) sb.writeln(n);
    } else if (_esMult) {
      for (final t in tickets) {
        sb.writeln("Ticket ${t['numero_ticket']}  ${t['loteria']}");
        if (t['pin'] != null) sb.writeln("PIN: ${t['pin']}");
      }
    } else {
      sb.writeln(p['loteria']?.toString() ?? '');
    }
    sb.writeln("Fecha: ${p['fecha'] ?? ''}");
    sb.writeln("Hora:  ${_hora(p['hora']?.toString())}");
    sb.writeln("----------------------------");
    sb.writeln("Tipo  Jugada    Cant  Monto");
    sb.writeln("----------------------------");
    for (final d in j) {
      sb.writeln("${(d['modalidad']??'').toString().padRight(5)} ${(d['numeros']??'').toString().padRight(9)} ${(d['cantidad']??'').toString().padRight(5)} \$${double.tryParse(d['monto']?.toString()??"0")?.toStringAsFixed(2)??'0.00'}");
    }
    sb.writeln("============================");
    sb.writeln("Total: \$${tot.toStringAsFixed(2)}");
    sb.writeln("============================");
    return sb.toString();
  }

  // ── Generar PDF bytes ─────────────────────────────
  Future<Uint8List> _generatePdf() async {
    final p   = tickets.first;
    final j   = _jugadasOrdenadas();
    final tot = tickets.fold(0.0,(s,t)=>s+(double.tryParse(t['total_monto']?.toString()??"0")??0));

    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat(80 * PdfPageFormat.mm,
          (120 + j.length * 8).toDouble() * PdfPageFormat.mm),
      margin: const pw.EdgeInsets.all(8 * PdfPageFormat.mm),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text("SuperBett", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text(banca, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Divider(thickness: 1.5),
          pw.Text("($_tipo)", style: pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 4),
          if (!_esMult) ...[
            pw.Text("Ticket # ${p['numero_ticket']}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            if (p['pin'] != null)
              pw.Text("PIN: ${p['pin']}", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          ],
          if (_esSP) ...((p['loterias_sp'] as List? ?? []).map((n) =>
              pw.Text(n.toString(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)))),
          if (_esMult) ...tickets.map((t) => pw.Column(children: [
            pw.Text("Ticket ${t['numero_ticket']}  ${t['loteria']}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            if (t['pin'] != null) pw.Text("PIN: ${t['pin']}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ])),
          if (!_esSP && !_esMult)
            pw.Text(p['loteria']?.toString() ?? '', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text("Fecha: ${p['fecha'] ?? ''}"),
          pw.Text("Hora:  ${_hora(p['hora']?.toString())}"),
          pw.Divider(),
          // Header jugadas
          pw.Row(children: [
            pw.SizedBox(width: 22, child: pw.Text("Tipo", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
            pw.Expanded(child: pw.Text("Jugada", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
            pw.SizedBox(width: 22, child: pw.Text("Cant", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
            pw.SizedBox(width: 32, child: pw.Text("Monto", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: pw.TextAlign.right)),
          ]),
          pw.Divider(thickness: 1),
          // Jugadas ordenadas Q→P→T
          ...j.map((d) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 1),
            child: pw.Row(children: [
              pw.SizedBox(width: 22, child: pw.Text(d['modalidad']?.toString() ?? '', style: const pw.TextStyle(fontSize: 9))),
              pw.Expanded(child: pw.Text(d['numeros']?.toString() ?? '', style: const pw.TextStyle(fontSize: 9))),
              pw.SizedBox(width: 22, child: pw.Text(d['cantidad']?.toString() ?? '', style: const pw.TextStyle(fontSize: 9))),
              pw.SizedBox(width: 32, child: pw.Text(
                "\$${double.tryParse(d['monto']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'}",
                style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
            ]))),
          pw.Divider(thickness: 1.5),
          pw.Text("Total  \$${tot.toStringAsFixed(2)}",
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    ));
    return doc.save();
  }

  // ── Acciones PDF ──────────────────────────────────
  Future<void> _guardarPdf(BuildContext context) async {
    try {
      final bytes = await _generatePdf();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'ticket_${tickets.first['numero_ticket']}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error PDF: $e"), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _imprimirPdf(BuildContext context) async {
    try {
      final bytes = await _generatePdf();
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'ticket_${tickets.first['numero_ticket']}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error imprimir: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p   = tickets.first;
    final j   = _jugadasOrdenadas();   // ← siempre Q → P → T → SP
    final tot = tickets.fold(0.0,(s,t)=>s+(double.tryParse(t['total_monto']?.toString()??"0")??0));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      // ── FIX horizontal: limitar ancho máximo ──────
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // ── Preview ticket ─────────────────────────
          Flexible(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12,12,12,0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black45, width: 1.5, style: BorderStyle.solid)),
              child: DefaultTextStyle(
                style: const TextStyle(fontFamily: 'monospace', color: Colors.black, fontSize: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  const Text("SuperBett", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  Text(banca, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text("($_tipo)", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  const Divider(thickness: 2, color: Colors.black),
                  if (!_esMult) ...[
                    _il("Ticket # ${p['numero_ticket']}"),
                    if (p['pin'] != null)
                      _il("PIN: ${p['pin']}"),
                  ],
                  if (_esSP) ...((p['loterias_sp'] as List<dynamic>? ?? []).map((n)=>_il(n.toString())))
                  else if (_esMult) ...tickets.map((t)=>Column(children:[
                    _il("Ticket ${t['numero_ticket']}  ${t['loteria']}"),
                    if (t['pin']!=null) _il("PIN: ${t['pin']}"),
                  ]))
                  else _il(p['loteria']?.toString()??''),
                  _il("Fecha: ${p['fecha']??''}"),
                  _il("Hora:  ${_hora(p['hora']?.toString())}"),
                  const Divider(color: Colors.grey),
                  // ── Encabezado tabla ───────────────
                  Row(children: const [
                    SizedBox(width:38, child:Text("Tipo",
                        overflow:TextOverflow.clip, maxLines:1,
                        style:TextStyle(fontWeight:FontWeight.bold, fontSize:11))),
                    Expanded(child:Text("Jugada",
                        style:TextStyle(fontWeight:FontWeight.bold, fontSize:11))),
                    SizedBox(width:38, child:Text("Cant",
                        overflow:TextOverflow.clip, maxLines:1,
                        style:TextStyle(fontWeight:FontWeight.bold, fontSize:11))),
                    SizedBox(width:56, child:Text("Monto",
                        textAlign:TextAlign.right,
                        style:TextStyle(fontWeight:FontWeight.bold, fontSize:11))),
                  ]),
                  const Divider(thickness: 1.5, color: Colors.black),
                  // ── Jugadas: Q primero, luego P, T ─
                  ...j.map((d) => Padding(padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      SizedBox(width:38, child:Text(d['modalidad']?.toString()??'',
                          overflow:TextOverflow.clip, maxLines:1,
                          style:const TextStyle(color:Color(0xFF007BFF), fontSize:11, fontWeight:FontWeight.bold))),
                      Expanded(child:Text(d['numeros']?.toString()??'',
                          style:const TextStyle(fontSize:11, fontWeight:FontWeight.bold))),
                      SizedBox(width:38, child:Text(d['cantidad']?.toString()??'',
                          overflow:TextOverflow.clip, maxLines:1,
                          style:const TextStyle(fontSize:11))),
                      SizedBox(width:56, child:Text(
                        "\$${double.tryParse(d['monto']?.toString()??"0")?.toStringAsFixed(2)}",
                        textAlign:TextAlign.right, style:const TextStyle(fontSize:11))),
                    ]))),
                  const Divider(thickness: 2, color: Colors.black),
                  Text("Total  \$${tot.toStringAsFixed(2)}",
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.green)),
                ]),
              ),
            ),
          )),

          // ── Botones ────────────────────────────────
          Padding(padding: const EdgeInsets.all(10), child: Column(children: [
            // Fila 1: Guardar PDF + Imprimir
            Row(children: [
              Expanded(child: ElevatedButton.icon(
                onPressed: () => _guardarPdf(context),
                icon: const Icon(Icons.picture_as_pdf, size: 16),
                label: const Text("Guardar PDF"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF28A745), foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10)))),
              const SizedBox(width: 7),
              Expanded(child: ElevatedButton.icon(
                onPressed: () => _imprimirPdf(context),
                icon: const Icon(Icons.print, size: 16),
                label: const Text("Imprimir"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6F42C1), foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10)))),
            ]),
            const SizedBox(height: 6),
            // Fila 2: Compartir PDF + Reusar Jugadas
            Row(children: [
              Expanded(child: ElevatedButton.icon(
                onPressed: () async {
                  final bytes = await _generatePdf();
                  final filename = 'ticket_${p['numero_ticket']}.pdf';
                  final xfile = XFile.fromData(bytes, mimeType: 'application/pdf', name: filename);
                  await Share.shareXFiles([xfile], subject: "Ticket #${p['numero_ticket']}");
                },
                icon: const Icon(Icons.share, size: 16),
                label: const Text("Compartir PDF"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF17A2B8), foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10)))),
              const SizedBox(width: 7),
              Expanded(child: ElevatedButton.icon(
                onPressed: () {
                  // Carga las jugadas del ticket de vuelta al formulario de venta
                  final jugadasRaw = tickets.first['jugadas'] as List? ?? [];
                  final jugadas = jugadasRaw.map((d) => _JugadaReusar(
                    modalidad: d['modalidad']?.toString() ?? '',
                    numeros:   d['numeros']?.toString()   ?? '',
                    cantidad:  int.tryParse(d['cantidad']?.toString() ?? '0') ?? 0,
                    monto:     double.tryParse(d['monto']?.toString() ?? '0') ?? 0,
                  )).where((j) => j.modalidad.isNotEmpty && j.numeros.isNotEmpty).toList();
                  Navigator.pop(context);   // cierra el dialog primero
                  onReusar(jugadas);        // luego pasa las jugadas al padre
                },
                icon: const Icon(Icons.replay, size: 16),
                label: const Text("Reusar"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6F42C1), foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10)))),
            ]),
            const SizedBox(height: 6),
            // Fila 3: Cerrar
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade600, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11)),
              child: const Text("Cerrar", style: TextStyle(fontWeight: FontWeight.bold)))),
          ])),
        ]),
      ),
    );
  }

  Widget _il(String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 1),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)));
}
