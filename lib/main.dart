import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String kApi = "https://superbett-api-production.up.railway.app/api";

void main() => runApp(const SuperBettApp());

class SuperBettApp extends StatelessWidget {
  const SuperBettApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'SuperBett POS',
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey), useMaterial3: true),
    home: const LoginPage(),
  );
}

// ─────────────────────────────────────────
// HELPERS GLOBALES
// ─────────────────────────────────────────
Future<Map<String, dynamic>> apiFetch(String path, String token,
    {String method = "GET", Map<String, dynamic>? body}) async {
  final uri     = Uri.parse('$kApi$path');
  final headers = {"Content-Type": "application/json", "Authorization": "Bearer $token"};
  http.Response r;
  if (method == "POST") {
    r = await http.post(uri, headers: headers, body: jsonEncode(body ?? {}));
  } else {
    r = await http.get(uri, headers: headers);
  }
  final data = jsonDecode(r.body) as Map<String, dynamic>;
  if (!r.statusCode.toString().startsWith("2")) {
    throw Exception(data['error'] ?? data['mensaje'] ?? "Error ${r.statusCode}");
  }
  return data;
}

String fmtMonto(double v) => "\$${v.toStringAsFixed(2)}";

void snack(BuildContext ctx, String msg, {Color bg = Colors.blueGrey}) =>
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));

// ══════════════════════════════════════════════════════════
// 1. LOGIN
// ══════════════════════════════════════════════════════════
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override State<LoginPage> createState() => _LoginPageState();
}
class _LoginPageState extends State<LoginPage> {
  final _userCtrl = TextEditingController();
  final _pinCtrl  = TextEditingController();
  String _msg = "Ingrese usuario y PIN";
  bool _loading = false;

  Future<void> _login() async {
    final user = _userCtrl.text.trim().toLowerCase();
    final pin  = _pinCtrl.text.trim();
    if (user.isEmpty || pin.isEmpty) { setState(() => _msg = "Ingrese usuario y PIN"); return; }
    setState(() { _loading = true; _msg = "Validando..."; });
    try {
      final r = await http.post(
        Uri.parse('https://superbett-api-production.up.railway.app/api/auth/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": user, "password": pin}),
      );
      final data = jsonDecode(r.body);
      if (r.statusCode == 200) {
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => MenuPage(userData: data['usuario'], token: data['token'])));
      } else {
        setState(() { _msg = data['error'] ?? "Credenciales inválidas"; _pinCtrl.clear(); });
      }
    } catch (_) { setState(() => _msg = "Error de conexión"); }
    finally { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(32), child: Column(children: [
      const Icon(Icons.account_balance_wallet, size: 80, color: Colors.blueGrey),
      const SizedBox(height: 10),
      const Text("SUPERBETT POS", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      Text(_msg, style: TextStyle(color: Colors.blueGrey.shade600)),
      const SizedBox(height: 30),
      TextField(controller: _userCtrl,
        decoration: const InputDecoration(labelText: "Usuario", border: OutlineInputBorder())),
      const SizedBox(height: 15),
      TextField(controller: _pinCtrl, obscureText: true, keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: "PIN", border: OutlineInputBorder())),
      const SizedBox(height: 25),
      _loading ? const CircularProgressIndicator()
        : SizedBox(width: double.infinity, height: 50,
            child: ElevatedButton(onPressed: _login,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
              child: const Text("INGRESAR"))),
    ]))),
  );
}

// ══════════════════════════════════════════════════════════
// 2. MENÚ PRINCIPAL
// ══════════════════════════════════════════════════════════
class MenuPage extends StatelessWidget {
  final Map<String, dynamic> userData;
  final String token;
  const MenuPage({super.key, required this.userData, required this.token});

  @override
  Widget build(BuildContext context) {
    final items = [
      {'title': 'Venta',            'icon': Icons.shopping_cart},
      {'title': 'Lista de Ventas',  'icon': Icons.list_alt},
      {'title': 'Lista de Tickets', 'icon': Icons.confirmation_number},
      {'title': 'Reportes',         'icon': Icons.bar_chart},
      {'title': 'Anular Ticket',    'icon': Icons.delete_forever},
      {'title': 'Pago de Ticket',   'icon': Icons.attach_money},
      {'title': 'Configuración',    'icon': Icons.settings},
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text("Menú Principal"),
        backgroundColor: Colors.blueGrey, foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.logout),
          onPressed: () => Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const LoginPage())))],
      ),
      body: Column(children: [
        Container(padding: const EdgeInsets.all(14), color: Colors.blueGrey.shade50,
          width: double.infinity,
          child: Text("Bienvenido: ${userData['nombre'] ?? userData['username']} (${userData['rol']})",
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
            textAlign: TextAlign.center)),
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: items.length,
          itemBuilder: (ctx, i) => Card(child: ListTile(
            leading: Icon(items[i]['icon'] as IconData, color: Colors.blueGrey),
            title: Text(items[i]['title'] as String),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              final t = items[i]['title'];
              Widget? page;
              if (t == 'Venta')            page = VentaPage(userData: userData, token: token);
              if (t == 'Lista de Ventas')  page = ListaVentasPage(userData: userData, token: token);
              if (t == 'Lista de Tickets') page = ListaTicketsPage(userData: userData, token: token);
              if (t == 'Reportes')         page = ReportesPage(userData: userData, token: token);
              if (t == 'Anular Ticket')    page = AnularTicketPage(userData: userData, token: token);
              if (t == 'Pago de Ticket')   page = PagarTicketPage(userData: userData, token: token);
              if (t == 'Configuración')    page = ConfiguracionPage(userData: userData, token: token);
              if (page != null) Navigator.push(ctx, MaterialPageRoute(builder: (_) => page!));
            },
          )),
        )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 3. VENTA  (con modo: Normal | Múltiple | Super Palé)
// ══════════════════════════════════════════════════════════
class VentaPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String token;
  const VentaPage({super.key, required this.userData, required this.token});
  @override State<VentaPage> createState() => _VentaPageState();
}

class _VentaPageState extends State<VentaPage> {
  final _numCtrl  = TextEditingController();
  final _cantCtrl = TextEditingController();

  List<Map<String, dynamic>> _jugadas  = [];
  List<dynamic>              _jornadas = [];
  String? _jornadaId;

  // Modo de venta: "normal" | "multiple" | "superpale"
  String _modo = "normal";

  // Para modo múltiple: jornadas seleccionadas
  final Set<String> _jornadasSelec = {};

  bool   _loading = true, _sending = false;
  double _total   = 0;

  @override void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    try {
      final d = await apiFetch('/jornadas/abiertas', widget.token);
      setState(() {
        _jornadas = d['jornadas'] ?? [];
        if (_jornadas.isNotEmpty) {
          _jornadaId = _jornadas[0]['jornada_id'].toString();
        }
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  void _agregar() {
    final num  = _numCtrl.text.trim();
    final cant = int.tryParse(_cantCtrl.text.trim()) ?? 0;
    if (num.isEmpty || cant <= 0) return;

    String mod;
    if (_modo == "superpale") {
      // Super Palé: 4 dígitos modalidad SP
      if (num.length != 4) { snack(context, "Super Palé requiere 4 dígitos", bg: Colors.orange); return; }
      mod = "SP";
    } else {
      mod = num.length == 2 ? "Q" : num.length == 4 ? "P" : num.length == 6 ? "T" : "";
      if (mod.isEmpty) { snack(context, "2 dígitos=Q, 4=Palé, 6=Tripleta", bg: Colors.orange); return; }
    }

    if (_modo == "multiple" && _jornadasSelec.isEmpty) {
      snack(context, "Seleccione al menos una lotería", bg: Colors.orange); return;
    }

    setState(() {
      _jugadas.add({"modalidad": mod, "numeros": num, "cantidad": cant, "monto": cant.toDouble()});
      _total += cant;
      _numCtrl.clear(); _cantCtrl.clear();
    });
  }

  Future<void> _vender() async {
    if (_jugadas.isEmpty) return;
    if (_modo == "normal"    && _jornadaId == null) return;
    if (_modo == "multiple"  && _jornadasSelec.isEmpty) return;
    if (_modo == "superpale" && _jornadaId == null) return;

    setState(() => _sending = true);
    try {
      Map<String, dynamic> bodyData;
      if (_modo == "multiple") {
        bodyData = {"jornadas": _jornadasSelec.toList(), "jugadas": _jugadas};
      } else if (_modo == "superpale") {
        bodyData = {"jornada_id": _jornadaId, "jugadas": _jugadas, "tipo": "super_pale"};
      } else {
        bodyData = {"jornada_id": _jornadaId, "jugadas": _jugadas};
      }

      final d = await apiFetch('/tickets', widget.token, method: "POST", body: bodyData);
      if (!mounted) return;
      showDialog(context: context, builder: (ctx) => AlertDialog(
        title: const Text("¡Venta Exitosa!"),
        content: Text("Ticket #${d['numero_ticket']} generado."),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
      ));
      setState(() { _jugadas.clear(); _total = 0; _jornadasSelec.clear(); });
    } catch (e) {
      snack(context, e.toString(), bg: Colors.red);
    } finally { setState(() => _sending = false); }
  }

  // Widget selector de modo
  Widget _selectorModo() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: Row(children: [
      Expanded(child: _modoBtn("normal",    "Normal",    Colors.blueGrey)),
      const SizedBox(width: 6),
      Expanded(child: _modoBtn("multiple",  "Múltiple",  Colors.indigo)),
      const SizedBox(width: 6),
      Expanded(child: _modoBtn("superpale", "Super Palé",Colors.deepPurple)),
    ]),
  );

  Widget _modoBtn(String modo, String label, Color color) => ElevatedButton(
    onPressed: () => setState(() { _modo = modo; _jugadas.clear(); _total = 0; _jornadasSelec.clear(); }),
    style: ElevatedButton.styleFrom(
      backgroundColor: _modo == modo ? color : Colors.grey.shade300,
      foregroundColor: _modo == modo ? Colors.white : Colors.black54,
      padding: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
  );

  // Selector de jornada(s) según modo
  Widget _selectorJornada() {
    if (_modo == "multiple") {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(left: 12, bottom: 4),
          child: Text("Seleccione Loterías:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        SizedBox(height: 48,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12),
            children: _jornadas.map((j) {
              final id = j['jornada_id'].toString();
              final sel = _jornadasSelec.contains(id);
              return Padding(padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(j['nombre'], style: const TextStyle(fontSize: 12)),
                  selected: sel,
                  onSelected: (_) => setState(() => sel ? _jornadasSelec.remove(id) : _jornadasSelec.add(id)),
                  selectedColor: Colors.indigo.shade100,
                  checkmarkColor: Colors.indigo,
                ));
            }).toList())),
      ]);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonFormField<String>(
        value: _jornadaId,
        items: _jornadas.map((j) => DropdownMenuItem(
          value: j['jornada_id'].toString(),
          child: Text(j['nombre'], style: const TextStyle(fontSize: 12)))).toList(),
        onChanged: (v) => setState(() => _jornadaId = v),
        decoration: const InputDecoration(border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8))));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Venta SuperBett"),
        backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
    body: _loading ? const Center(child: CircularProgressIndicator())
      : Column(children: [
          // Header usuario
          Container(color: Colors.blueGrey.shade700, width: double.infinity, padding: const EdgeInsets.all(8),
            child: Text("${widget.userData['nombre']} — ${widget.userData['username']}",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center)),
          // Selector de modo
          _selectorModo(),
          // Selector lotería / loterías
          _selectorJornada(),
          const SizedBox(height: 8),
          // Total + campos entrada
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
            Expanded(child: TextField(controller: _numCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: "Número", border: OutlineInputBorder(), isDense: true))),
            const SizedBox(width: 5),
            SizedBox(width: 80, child: TextField(controller: _cantCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: "Cant", border: OutlineInputBorder(), isDense: true))),
            const SizedBox(width: 5),
            ElevatedButton(onPressed: _agregar,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey,
                  foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
              child: const Text("ADD")),
            const SizedBox(width: 5),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
              child: Text(fmtMonto(_total),
                style: const TextStyle(color: Colors.lime, fontWeight: FontWeight.bold))),
          ])),
          const SizedBox(height: 6),
          // Grid jugadas
          Expanded(child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, childAspectRatio: 1.4, crossAxisSpacing: 6, mainAxisSpacing: 6),
            itemCount: _jugadas.length,
            itemBuilder: (_, i) {
              final item = _jugadas[i];
              return Card(elevation: 3, child: Stack(children: [
                Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text("${item['modalidad']} ${item['numeros']}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(fmtMonto(item['monto']),
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ])),
                Positioned(right: -10, top: -10, child: IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red, size: 18),
                  onPressed: () => setState(() { _total -= _jugadas[i]['monto']; _jugadas.removeAt(i); }))),
              ]));
            },
          )),
          // Botones VENDER / LIMPIAR
          Padding(padding: const EdgeInsets.all(10), child: Row(children: [
            Expanded(child: ElevatedButton(
              onPressed: _sending ? null : _vender,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green,
                  foregroundColor: Colors.white, padding: const EdgeInsets.all(14)),
              child: _sending ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("VENDER", style: TextStyle(fontWeight: FontWeight.bold)))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              onPressed: () => setState(() { _jugadas.clear(); _total = 0; _jornadasSelec.clear(); }),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange,
                  foregroundColor: Colors.white, padding: const EdgeInsets.all(14)),
              child: const Text("LIMPIAR"))),
          ])),
        ]),
  );
}

// ══════════════════════════════════════════════════════════
// 4. LISTA DE VENTAS
// ══════════════════════════════════════════════════════════
class ListaVentasPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String token;
  const ListaVentasPage({super.key, required this.userData, required this.token});
  @override State<ListaVentasPage> createState() => _ListaVentasPageState();
}
class _ListaVentasPageState extends State<ListaVentasPage> {
  DateTime _fecha      = DateTime.now();
  String   _loteriaId = "TODAS";
  List<Map<String, dynamic>> _loterias = [];
  Map<String, List<Map<String, dynamic>>> _porMod = {};
  double _totalGeneral = 0;
  bool   _loading = true;
  String _error   = "";

  String get _fechaStr {
    final f = _fecha;
    return "${f.year}-${f.month.toString().padLeft(2,'0')}-${f.day.toString().padLeft(2,'0')}";
  }

  @override void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = ""; });
    try {
      String path = '/tickets/ventas-lista?fecha=$_fechaStr';
      if (_loteriaId != "TODAS" && _loteriaId != "SUPER_PALE") path += '&loteria_id=$_loteriaId';
      final data = await apiFetch(path, widget.token);

      final lots = (data['loterias'] as List? ?? [])
          .map((l) => {'id': l['id'].toString(), 'nombre': l['nombre'].toString()}).toList();

      final Map<String, List<Map<String, dynamic>>> mods = {"Q": [], "P": [], "T": [], "SP": []};
      for (final r in (data['normales'] as List? ?? [])) {
        if (_loteriaId == "SUPER_PALE") continue;
        final mod = r['modalidad']?.toString() ?? "";
        if (mods.containsKey(mod)) {
          mods[mod]!.add({'loteria': r['loteria']?.toString() ?? "",
            'jugada': r['jugada']?.toString() ?? "",
            'cantidad': double.tryParse(r['cantidad']?.toString() ?? "0") ?? 0,
            'monto': double.tryParse(r['monto']?.toString() ?? "0") ?? 0});
        }
      }
      if (_loteriaId == "SUPER_PALE" || _loteriaId == "TODAS") {
        for (final r in (data['super_pale'] as List? ?? [])) {
          mods['SP']!.add({'loteria': r['loteria']?.toString() ?? "",
            'jugada': r['jugada']?.toString() ?? "",
            'cantidad': double.tryParse(r['cantidad']?.toString() ?? "0") ?? 0,
            'monto': double.tryParse(r['monto']?.toString() ?? "0") ?? 0});
        }
      }
      setState(() {
        _loterias     = lots;
        _porMod       = mods;
        _totalGeneral = double.tryParse(data['total_general']?.toString() ?? "0") ?? 0;
        _loading      = false;
      });
    } catch (e) { setState(() { _loading = false; _error = e.toString(); }); }
  }

  Future<void> _pickFecha() async {
    final p = await showDatePicker(context: context, initialDate: _fecha,
        firstDate: DateTime(2024), lastDate: DateTime.now());
    if (p != null) { setState(() => _fecha = p); _cargar(); }
  }

  @override
  Widget build(BuildContext context) {
    final hasData = _porMod.values.any((v) => v.isNotEmpty);
    return Scaffold(
      appBar: AppBar(title: const Text("Venta por Lista"),
          backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(10), child: Row(children: [
          Expanded(child: DropdownButtonFormField<String>(
            value: _loteriaId,
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
            items: [
              const DropdownMenuItem(value: "TODAS", child: Text("Todas")),
              ..._loterias.map((l) => DropdownMenuItem(value: l['id'], child: Text(l['nombre']!))),
              const DropdownMenuItem(value: "SUPER_PALE", child: Text("Super Pale")),
            ],
            onChanged: (v) { if (v != null) { setState(() => _loteriaId = v); _cargar(); } },
          )),
          const SizedBox(width: 8),
          OutlinedButton.icon(onPressed: _pickFecha,
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text("${_fecha.day.toString().padLeft(2,'0')}-${_fecha.month.toString().padLeft(2,'0')}-${_fecha.year}",
                style: const TextStyle(fontSize: 13))),
        ])),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
            ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
            : !hasData
              ? const Center(child: Text("No hay ventas para esta fecha.", style: TextStyle(color: Colors.grey)))
              : RefreshIndicator(onRefresh: _cargar, child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  children: [
                    ..._porMod.entries.where((e) => e.value.isNotEmpty).map((e) {
                      final mod   = e.key;
                      final filas = e.value;
                      final total = filas.fold(0.0, (s, f) => s + (f['monto'] as double));
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Padding(padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(mod, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                        Table(border: TableBorder.all(color: Colors.grey.shade300),
                          columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(2),
                              2: FlexColumnWidth(1), 3: FlexColumnWidth(1.5)},
                          children: [
                            TableRow(decoration: BoxDecoration(color: Colors.grey.shade100),
                              children: ['Lotería','Jugada','Cant','Monto'].map((h) =>
                                Padding(padding: const EdgeInsets.all(6),
                                  child: Text(h, style: const TextStyle(fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center))).toList()),
                            ...filas.map((f) => TableRow(children: [
                              Padding(padding: const EdgeInsets.all(6), child: Text(f['loteria'], textAlign: TextAlign.center)),
                              Padding(padding: const EdgeInsets.all(6), child: Text(f['jugada'],  textAlign: TextAlign.center)),
                              Padding(padding: const EdgeInsets.all(6), child: Text((f['cantidad'] as double).toStringAsFixed(0), textAlign: TextAlign.center)),
                              Padding(padding: const EdgeInsets.all(6), child: Text(fmtMonto(f['monto']), textAlign: TextAlign.center)),
                            ])),
                          ]),
                        Align(alignment: Alignment.centerRight,
                          child: Padding(padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text("Total $mod: ${fmtMonto(total)}", style: const TextStyle(fontWeight: FontWeight.bold)))),
                        const Divider(),
                      ]);
                    }),
                    if (hasData) Padding(padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text("Total General: ${fmtMonto(_totalGeneral)}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          textAlign: TextAlign.right)),
                  ],
                ))),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 5. LISTA DE TICKETS
// ══════════════════════════════════════════════════════════
class ListaTicketsPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String token;
  const ListaTicketsPage({super.key, required this.userData, required this.token});
  @override State<ListaTicketsPage> createState() => _ListaTicketsPageState();
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

  String get _fechaStr => "${_fecha.year}-${_fecha.month.toString().padLeft(2,'0')}-${_fecha.day.toString().padLeft(2,'0')}";

  @override void initState() { super.initState(); _cargar(); }

  Future<void> _cargar({String busq = ""}) async {
    setState(() { _loading = true; _error = ""; });
    try {
      if (busq.length >= 3) {
        final d = await apiFetch('/tickets/${busq.toUpperCase()}', widget.token);
        if (d['jugadas'] != null) { _jugadasCache[d['numero_ticket'].toString()] = d['jugadas']; }
        setState(() { _tickets = [d]; _loading = false; });
      } else {
        final d = await apiFetch('/tickets?fecha=$_fechaStr', widget.token);
        setState(() { _tickets = d['tickets'] ?? []; _loading = false; });
      }
    } catch (e) { setState(() { _loading = false; _error = e.toString(); }); }
  }

  Future<void> _pickFecha() async {
    final p = await showDatePicker(context: context, initialDate: _fecha,
        firstDate: DateTime(2024), lastDate: DateTime.now());
    if (p != null) { setState(() { _fecha = p; _expandidos.clear(); }); _cargar(); }
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
    final ganado   = double.tryParse(t['total_ganado']?.toString() ?? "0") ?? 0;
    final pendiente= int.tryParse(t['premios_pendientes']?.toString() ?? "0") ?? 0;
    Color bg; Color fg; String label;
    if (anulado)                           { bg = const Color(0xFFF8D7DA); fg = const Color(0xFFB02A37); label = "ANULADO"; }
    else if (ganado > 0 && pendiente == 0) { bg = const Color(0xFFD1E7DD); fg = const Color(0xFF0F5132); label = "PAGADO"; }
    else if (ganado > 0)                   { bg = const Color(0xFFFFF3CD); fg = const Color(0xFF856404); label = "GANADOR ${fmtMonto(ganado)}"; }
    else return const SizedBox.shrink();
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11)));
  }

  Widget _tarjeta(Map t) {
    final num      = t['numero_ticket']?.toString() ?? "";
    final anulado  = t['anulado'] == true || t['anulado'] == 1;
    final monto    = double.tryParse(t['total_monto']?.toString() ?? "0") ?? 0;
    final ganado   = double.tryParse(t['total_ganado']?.toString() ?? "0") ?? 0;
    final pendiente= int.tryParse(t['premios_pendientes']?.toString() ?? "0") ?? 0;
    final expand   = _expandidos.contains(num);

    return Card(margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: anulado ? const Color(0xFFF5C2C7) : Colors.grey.shade300)),
      color: anulado ? const Color(0xFFFFF5F5) : Colors.white,
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.vertical(top: const Radius.circular(10),
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
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: anulado ? const Color(0xFFF8D7DA) : Colors.grey.shade100,
              borderRadius: BorderRadius.vertical(top: const Radius.circular(10),
                  bottom: expand ? Radius.zero : const Radius.circular(10))),
            child: Row(children: [
              Text(num, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15,
                  color: anulado ? const Color(0xFFB02A37) : Colors.black)),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("${_fmtFecha(t['fecha']?.toString())} ${_fmtHora(t['hora']?.toString())}",
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                if ((t['loteria'] ?? "").toString().isNotEmpty)
                  Text(t['loteria'].toString(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ])),
              _badge(t as Map<dynamic, dynamic>),
              const SizedBox(width: 6),
              Text(fmtMonto(monto), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15,
                  color: anulado ? const Color(0xFFB02A37) : const Color(0xFF198754),
                  decoration: anulado ? TextDecoration.lineThrough : null)),
              const SizedBox(width: 4),
              Icon(expand ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey),
            ]),
          ),
        ),
        if (expand) ...[
          const Divider(height: 1),
          _jugadasCache.containsKey(num)
            ? Column(children: (_jugadasCache[num] ?? []).map<Widget>((j) {
                final prem = double.tryParse(j['premio']?.toString() ?? "0") ?? 0;
                return Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  child: Row(children: [
                    SizedBox(width: 28, child: Text(j['modalidad']?.toString() ?? "",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D6EFD)))),
                    Expanded(child: Text(j['numeros']?.toString() ?? "",
                        style: const TextStyle(fontWeight: FontWeight.bold))),
                    Text("× ${j['cantidad']}", style: const TextStyle(color: Colors.grey)),
                    const SizedBox(width: 8),
                    Text(fmtMonto(double.tryParse(j['monto']?.toString() ?? "0") ?? 0),
                        style: const TextStyle(color: Color(0xFF198754), fontWeight: FontWeight.bold)),
                    if (prem > 0) ...[const SizedBox(width: 6),
                      Text("🏆 ${fmtMonto(prem)}",
                          style: const TextStyle(color: Color(0xFFDC3545), fontWeight: FontWeight.bold, fontSize: 12))],
                  ]));
              }).toList())
            : const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(children: [
              Expanded(child: ElevatedButton.icon(
                onPressed: () => snack(context, "Copiar: próximamente"),
                icon: const Icon(Icons.copy, size: 15),
                label: const Text("Copiar", style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D6EFD), foregroundColor: Colors.white))),
              if (!anulado && ganado == 0) ...[const SizedBox(width: 6),
                Expanded(child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => AnularTicketPage(userData: {}, token: widget.token, prefill: num))),
                  icon: const Icon(Icons.cancel, size: 15),
                  label: const Text("Anular", style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC3545), foregroundColor: Colors.white)))],
              if (ganado > 0 && pendiente > 0) ...[const SizedBox(width: 6),
                Expanded(child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => PagarTicketPage(userData: {}, token: widget.token, prefill: num))),
                  icon: const Icon(Icons.attach_money, size: 15),
                  label: const Text("Pagar", style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF198754), foregroundColor: Colors.white)))],
            ])),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Tickets Vendidos"),
        backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(10), child: Row(children: [
        Expanded(child: TextField(controller: _searchCtrl, onChanged: _onSearch,
          decoration: const InputDecoration(hintText: "Buscar número ticket",
              prefixIcon: Icon(Icons.search), border: OutlineInputBorder(),
              isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)))),
        const SizedBox(width: 8),
        OutlinedButton.icon(onPressed: _pickFecha,
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text("${_fecha.day.toString().padLeft(2,'0')}-${_fecha.month.toString().padLeft(2,'0')}-${_fecha.year}",
              style: const TextStyle(fontSize: 13))),
      ])),
      Expanded(child: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error.isNotEmpty
          ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
          : _tickets.isEmpty
            ? const Center(child: Text("No hay tickets para esta fecha.", style: TextStyle(color: Colors.grey)))
            : RefreshIndicator(onRefresh: _cargar,
                child: ListView.builder(itemCount: _tickets.length,
                    itemBuilder: (_, i) => _tarjeta(_tickets[i] as Map)))),
    ]),
  );
}

// ══════════════════════════════════════════════════════════
// 6. REPORTES
// ══════════════════════════════════════════════════════════
class ReportesPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String token;
  const ReportesPage({super.key, required this.userData, required this.token});
  @override State<ReportesPage> createState() => _ReportesPageState();
}
class _ReportesPageState extends State<ReportesPage> {
  DateTime _fecha    = DateTime.now();
  int      _tabIndex = 0;
  bool     _loading  = false;
  String   _error    = "";
  Map<String, dynamic> _data = {};

  String get _fechaStr => "${_fecha.year}-${_fecha.month.toString().padLeft(2,'0')}-${_fecha.day.toString().padLeft(2,'0')}";
  String _fmt(dynamic n) => fmtMonto(double.tryParse(n?.toString() ?? "0") ?? 0);

  @override void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = ""; });
    try {
      final d = await apiFetch('/reportes/banca?fecha=$_fechaStr', widget.token);
      setState(() { _data = d; _loading = false; });
    } catch (e) { setState(() { _error = e.toString(); _loading = false; }); }
  }

  Future<void> _pickFecha() async {
    final p = await showDatePicker(context: context, initialDate: _fecha,
        firstDate: DateTime(2024), lastDate: DateTime.now());
    if (p != null) { setState(() => _fecha = p); _cargar(); }
  }

  Widget _resumen() {
    final r       = (_data['resumen'] as Map?) ?? {};
    final venta   = double.tryParse(r['total_venta']?.toString()    ?? "0") ?? 0;
    final comis   = double.tryParse(r['total_comision']?.toString() ?? "0") ?? 0;
    final premios = double.tryParse(r['total_premios']?.toString()  ?? "0") ?? 0;
    final result  = double.tryParse(r['resultado']?.toString()      ?? "0") ?? (venta - comis - premios);
    return SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(children: [
      _card("Resumen General", [
        _row("Total Tickets",      r['total_tickets']?.toString() ?? "0"),
        _row("Tickets Anulados",   r['tickets_anulados']?.toString() ?? "0"),
        _row("Venta Total",        _fmt(venta)),
        _rowC("Comisión Banca",    _fmt(comis), const Color(0xFF6F42C1)),
        _row("Premios",            "(${_fmt(premios)})"),
        _rowB("Resultado Neto",    _fmt(result), result >= 0 ? const Color(0xFF198754) : const Color(0xFFDC3545)),
        _row("Premios Pendientes", r['premios_pendientes']?.toString() ?? "0"),
      ]),
    ]));
  }

  Widget _modalidad() {
    final mods = (_data['por_modalidad'] as List?) ?? [];
    if (mods.isEmpty) return const Center(child: Text("Sin datos por modalidad.", style: TextStyle(color: Colors.grey)));
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
          _row("Tickets",    m['tickets']?.toString() ?? "0"),
          _rowC("% Comisión", "${pct.toStringAsFixed(1)}%", const Color(0xFF6F42C1)),
          _row("Venta",      _fmt(v)),
          _rowC("Comisión",  _fmt(c), const Color(0xFF6F42C1)),
        ]);
      }),
      _card("RESULTADO", [
        _row("Venta Bruta", _fmt(tV)),
        _rowC("Comisión", "(${_fmt(tC)})", const Color(0xFF6F42C1)),
        _row("Premios", "(${_fmt(tP)})"),
        _rowB("Resultado Neto", _fmt(tR), tR >= 0 ? const Color(0xFF198754) : const Color(0xFFDC3545)),
      ], hColor: Colors.grey.shade700),
    ]));
  }

  Widget _loteria() {
    final lots = (_data['por_loteria'] as List?) ?? [];
    if (lots.isEmpty) return const Center(child: Text("Sin detalles por lotería.", style: TextStyle(color: Colors.grey)));
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
          _row("Venta",     _fmt(v)),
          _rowC("Comisión", "(${_fmt(c)})", const Color(0xFF6F42C1)),
          _row("Premios",   "(${_fmt(p)})"),
          _rowB("Resultado", _fmt(neto), neto >= 0 ? const Color(0xFF198754) : const Color(0xFFDC3545)),
        ]);
      }),
      _card("RESULTADO TOTAL", [
        _row("Venta Bruta", _fmt(ltV)),
        _rowC("Comisión", "(${_fmt(ltC)})", const Color(0xFF6F42C1)),
        _row("Premios", "(${_fmt(ltP)})"),
        _rowB("Resultado Neto", _fmt(ltR), ltR >= 0 ? const Color(0xFF198754) : const Color(0xFFDC3545)),
      ], hColor: Colors.grey.shade700),
    ]));
  }

  Widget _card(String t, List<Widget> rows, {Color? hColor}) => Card(margin: const EdgeInsets.only(bottom: 12),
    child: Column(children: [
      Container(width: double.infinity, padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: hColor ?? Colors.blueGrey,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
        child: Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      ...rows,
    ]));

  Widget _row(String l, String v) => Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(children: [Expanded(child: Text(l, style: const TextStyle(color: Colors.black54))),
      Text(v, style: const TextStyle(fontWeight: FontWeight.w500))]));

  Widget _rowC(String l, String v, Color c) => Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(children: [Expanded(child: Text(l, style: const TextStyle(color: Colors.black54))),
      Text(v, style: TextStyle(fontWeight: FontWeight.bold, color: c))]));

  Widget _rowB(String l, String v, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: Colors.grey.shade100,
        border: Border(top: BorderSide(color: Colors.grey.shade400, width: 2))),
    child: Row(children: [Expanded(child: Text(l, style: const TextStyle(fontWeight: FontWeight.bold))),
      Text(v, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: c))]));

  @override
  Widget build(BuildContext context) {
    final tabs = ["Resumen", "Modalidad", "Lotería"];
    return Scaffold(
      appBar: AppBar(title: const Text("Reportes POS"),
          backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
      body: Column(children: [
        Container(padding: const EdgeInsets.all(8), color: Colors.blueGrey.shade50,
          child: Text("${widget.userData['nombre'] ?? widget.userData['username']} (${widget.userData['rol']})",
              style: const TextStyle(color: Colors.blueGrey), textAlign: TextAlign.center)),
        Padding(padding: const EdgeInsets.all(10), child: Row(children: [
          Expanded(child: ToggleButtons(
            isSelected: List.generate(3, (i) => i == _tabIndex),
            onPressed: (i) => setState(() => _tabIndex = i),
            borderRadius: BorderRadius.circular(8),
            selectedColor: Colors.white, fillColor: Colors.blueGrey,
            constraints: const BoxConstraints(minHeight: 36),
            children: tabs.map((t) => Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
          )),
          const SizedBox(width: 8),
          OutlinedButton.icon(onPressed: _pickFecha,
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text("${_fecha.day.toString().padLeft(2,'0')}-${_fecha.month.toString().padLeft(2,'0')}-${_fecha.year}",
                style: const TextStyle(fontSize: 13))),
        ])),
        ElevatedButton(onPressed: _cargar,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 42),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
          child: const Text("Generar Reporte")),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
            ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
            : _data.isEmpty
              ? const Center(child: Text("Presiona Generar Reporte"))
              : IndexedStack(index: _tabIndex, children: [_resumen(), _modalidad(), _loteria()])),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 7. ANULAR TICKET
// ══════════════════════════════════════════════════════════
class AnularTicketPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String token;
  final String prefill;
  const AnularTicketPage({super.key, required this.userData, required this.token, this.prefill = ""});
  @override State<AnularTicketPage> createState() => _AnularTicketPageState();
}
class _AnularTicketPageState extends State<AnularTicketPage> {
  final _ctrl = TextEditingController();
  Map<String, dynamic>? _ticket;
  bool _buscando = false, _anulando = false;
  String _error = "";

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
    } catch (e) { setState(() { _error = e.toString(); _buscando = false; }); }
  }

  Future<void> _anular() async {
    if (_ticket == null) return;
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Confirmar Anulación"),
      content: Text("¿Anular el ticket #${_ticket!['numero_ticket']}?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: const Text("Anular")),
      ],
    ));
    if (confirm != true) return;
    setState(() => _anulando = true);
    try {
      await apiFetch('/tickets/${_ticket!['numero_ticket']}/anular', widget.token, method: "POST");
      snack(context, "Ticket anulado correctamente ✓", bg: Colors.green);
      _buscar();
    } catch (e) { snack(context, e.toString(), bg: Colors.red); }
    finally { setState(() => _anulando = false); }
  }

  @override
  Widget build(BuildContext context) {
    final anulado = _ticket?['anulado'] == true || _ticket?['anulado'] == 1;
    final ganado  = double.tryParse(_ticket?['total_ganado']?.toString() ?? "0") ?? 0;
    final puedeAnular = _ticket != null && !anulado && ganado == 0;

    return Scaffold(
      appBar: AppBar(title: const Text("Anular Ticket"),
          backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
      body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        // Búsqueda
        Row(children: [
          Expanded(child: TextField(controller: _ctrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: "Número de Ticket", border: OutlineInputBorder()),
            onSubmitted: (_) => _buscar())),
          const SizedBox(width: 10),
          ElevatedButton(onPressed: _buscando ? null : _buscar,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16)),
            child: _buscando ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.search)),
        ]),
        const SizedBox(height: 16),

        // Error
        if (_error.isNotEmpty)
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(
              color: Colors.red.shade50, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200)),
            child: Text(_error, style: const TextStyle(color: Colors.red))),

        // Info del ticket
        if (_ticket != null) ...[
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text("Ticket: ${_ticket!['numero_ticket']}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 8),
              if (anulado) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(8)),
                child: const Text("ANULADO", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12))),
              if (ganado > 0) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(8)),
                child: const Text("GANADOR", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))),
            ]),
            const SizedBox(height: 6),
            Text("Total: ${fmtMonto(double.tryParse(_ticket!['total_monto']?.toString() ?? "0") ?? 0)}"),
            Text("Fecha: ${_ticket!['fecha'] ?? ""} ${_ticket!['hora'] ?? ""}"),
            const SizedBox(height: 10),
            const Text("Jugadas:", style: TextStyle(fontWeight: FontWeight.bold)),
            ...(_ticket!['jugadas'] as List? ?? []).map((j) => Padding(
              padding: const EdgeInsets.only(left: 10, top: 4),
              child: Text("${j['modalidad']} | ${j['numeros']} | Cant: ${j['cantidad']} | ${fmtMonto(double.tryParse(j['monto']?.toString() ?? "0") ?? 0)}",
                style: const TextStyle(fontSize: 13)))),
          ]))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: (!puedeAnular || _anulando) ? null : _anular,
            icon: _anulando ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.cancel),
            label: Text(anulado ? "Ya está anulado" : ganado > 0 ? "Ticket ganador (no anulable)" : "Anular Ticket"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white,
                padding: const EdgeInsets.all(14),
                disabledBackgroundColor: Colors.grey.shade300),
          )),
        ],
      ])),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 8. PAGAR TICKET
// ══════════════════════════════════════════════════════════
class PagarTicketPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String token;
  final String prefill;
  const PagarTicketPage({super.key, required this.userData, required this.token, this.prefill = ""});
  @override State<PagarTicketPage> createState() => _PagarTicketPageState();
}
class _PagarTicketPageState extends State<PagarTicketPage> {
  final _ctrl = TextEditingController();
  Map<String, dynamic>? _ticket;
  bool _buscando = false, _pagando = false;
  String _error = "";

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
    } catch (e) { setState(() { _error = e.toString(); _buscando = false; }); }
  }

  Future<void> _pagar() async {
    if (_ticket == null) return;
    final ganado = double.tryParse(_ticket!['total_ganado']?.toString() ?? "0") ?? 0;
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Confirmar Pago"),
      content: Text("¿Pagar el ticket #${_ticket!['numero_ticket']} por ${fmtMonto(ganado)}?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          child: const Text("Pagar")),
      ],
    ));
    if (confirm != true) return;
    setState(() => _pagando = true);
    try {
      await apiFetch('/tickets/${_ticket!['numero_ticket']}/pagar', widget.token, method: "POST");
      snack(context, "Ticket pagado correctamente ✓", bg: Colors.green);
      _buscar();
    } catch (e) { snack(context, e.toString(), bg: Colors.red); }
    finally { setState(() => _pagando = false); }
  }

  @override
  Widget build(BuildContext context) {
    final anulado  = _ticket?['anulado'] == true || _ticket?['anulado'] == 1;
    final ganado   = double.tryParse(_ticket?['total_ganado']?.toString() ?? "0") ?? 0;
    final pendiente= int.tryParse(_ticket?['premios_pendientes']?.toString() ?? "0") ?? 0;
    final puedePagar = _ticket != null && !anulado && ganado > 0 && pendiente > 0;

    return Scaffold(
      appBar: AppBar(title: const Text("Pago de Ticket"),
          backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
      body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        // Búsqueda
        Row(children: [
          Expanded(child: TextField(controller: _ctrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: "Número de Ticket", border: OutlineInputBorder()),
            onSubmitted: (_) => _buscar())),
          const SizedBox(width: 10),
          ElevatedButton(onPressed: _buscando ? null : _buscar,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16)),
            child: _buscando ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.search)),
        ]),
        const SizedBox(height: 16),

        if (_error.isNotEmpty)
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(
              color: Colors.red.shade50, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200)),
            child: Text(_error, style: const TextStyle(color: Colors.red))),

        if (_ticket != null) ...[
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text("Ticket: ${_ticket!['numero_ticket']}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 8),
              if (anulado) _chip("ANULADO", Colors.red),
              if (ganado > 0 && pendiente > 0) _chip("GANADOR", Colors.orange),
              if (ganado > 0 && pendiente == 0) _chip("PAGADO", Colors.green),
            ]),
            const SizedBox(height: 8),
            Text("Monto del ticket: ${fmtMonto(double.tryParse(_ticket!['total_monto']?.toString() ?? "0") ?? 0)}"),
            Text("Fecha: ${_ticket!['fecha'] ?? ""} ${_ticket!['hora'] ?? ""}"),
            if (ganado > 0) ...[
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.emoji_events, color: Colors.green),
                  const SizedBox(width: 8),
                  Text("Premio: ${fmtMonto(ganado)}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                ])),
            ],
            const SizedBox(height: 10),
            const Text("Jugadas:", style: TextStyle(fontWeight: FontWeight.bold)),
            ...(_ticket!['jugadas'] as List? ?? []).map((j) {
              final prem = double.tryParse(j['premio']?.toString() ?? "0") ?? 0;
              return Padding(padding: const EdgeInsets.only(left: 10, top: 4),
                child: Text(
                  "${j['modalidad']} | ${j['numeros']} | ${fmtMonto(double.tryParse(j['monto']?.toString() ?? "0") ?? 0)}"
                  "${prem > 0 ? ' → 🏆 ${fmtMonto(prem)}' : ''}",
                  style: TextStyle(fontSize: 13, color: prem > 0 ? Colors.green.shade700 : Colors.black)));
            }),
          ]))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: (!puedePagar || _pagando) ? null : _pagar,
            icon: _pagando ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.attach_money),
            label: Text(anulado ? "Ticket anulado" : ganado == 0 ? "Sin premio" : pendiente == 0 ? "Ya fue pagado" : "Pagar ${fmtMonto(ganado)}"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white,
                padding: const EdgeInsets.all(14),
                disabledBackgroundColor: Colors.grey.shade300),
          )),
        ],
      ])),
    );
  }

  Widget _chip(String label, Color color) => Container(
    margin: const EdgeInsets.only(left: 6),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4))),
    child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)));
}

// ══════════════════════════════════════════════════════════
// 9. CONFIGURACIÓN
// ══════════════════════════════════════════════════════════
class ConfiguracionPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String token;
  const ConfiguracionPage({super.key, required this.userData, required this.token});
  @override State<ConfiguracionPage> createState() => _ConfiguracionPageState();
}
class _ConfiguracionPageState extends State<ConfiguracionPage> {
  String _tipoSalida  = "impresora";
  String _anchoTicket = "80";
  bool   _guardado    = false;

  // En Flutter guardamos en memoria (sin localStorage).
  // Para persistir entre sesiones se puede agregar shared_preferences.

  Widget _grupo(String label, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
    const SizedBox(height: 8),
    child,
    const SizedBox(height: 20),
  ]);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Configuración"),
        backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
    body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
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

      // Animación guardado
      AnimatedContainer(duration: const Duration(milliseconds: 300),
        height: _guardado ? 44 : 0,
        child: _guardado ? Container(
          width: double.infinity, padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade300)),
          child: const Text("✓ Configuración guardada correctamente",
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center)) : const SizedBox()),

      const SizedBox(height: 10),

      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: () {
          setState(() => _guardado = true);
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _guardado = false);
          });
        },
        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue,
            foregroundColor: Colors.white, padding: const EdgeInsets.all(14)),
        child: const Text("Guardar Configuración", style: TextStyle(fontSize: 16)))),

      const SizedBox(height: 10),

      // Info usuario
      const Divider(),
      const SizedBox(height: 10),
      const Text("Sesión activa", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
      const SizedBox(height: 6),
      Text("${widget.userData['nombre'] ?? widget.userData['username'] ?? '-'}",
          style: const TextStyle(fontSize: 15)),
      Text("Rol: ${widget.userData['rol'] ?? '-'}", style: const TextStyle(color: Colors.grey)),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, child: OutlinedButton.icon(
        onPressed: () => Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false),
        icon: const Icon(Icons.logout, color: Colors.red),
        label: const Text("Cerrar Sesión", style: TextStyle(color: Colors.red)),
        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.all(14)))),
    ])),
  );
}
