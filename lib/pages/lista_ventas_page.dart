import 'package:flutter/material.dart';
import '../helpers.dart';

class ListaVentasPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String token;
  const ListaVentasPage({super.key, required this.userData, required this.token});
  @override
  State<ListaVentasPage> createState() => _ListaVentasPageState();
}

class _ListaVentasPageState extends State<ListaVentasPage> {
  DateTime _fecha     = DateTime.now();
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

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = ""; });
    try {
      String path = '/tickets/ventas-lista?fecha=$_fechaStr';
      if (_loteriaId != "TODAS" && _loteriaId != "SUPER_PALE") {
        path += '&loteria_id=$_loteriaId';
      }
      final data = await apiFetch(path, widget.token);

      final lots = (data['loterias'] as List? ?? [])
          .map((l) => {'id': l['id'].toString(), 'nombre': l['nombre'].toString()})
          .toList();

      final Map<String, List<Map<String, dynamic>>> mods = {
        "Q": [], "P": [], "T": [], "SP": []
      };

      for (final r in (data['normales'] as List? ?? [])) {
        if (_loteriaId == "SUPER_PALE") continue;
        final mod = r['modalidad']?.toString() ?? "";
        if (mods.containsKey(mod)) {
          mods[mod]!.add({
            'loteria':  r['loteria']?.toString() ?? "",
            'jugada':   r['jugada']?.toString()  ?? "",
            'cantidad': double.tryParse(r['cantidad']?.toString() ?? "0") ?? 0,
            'monto':    double.tryParse(r['monto']?.toString()    ?? "0") ?? 0,
          });
        }
      }

      if (_loteriaId == "SUPER_PALE" || _loteriaId == "TODAS") {
        for (final r in (data['super_pale'] as List? ?? [])) {
          mods['SP']!.add({
            'loteria':  r['loteria']?.toString() ?? "",
            'jugada':   r['jugada']?.toString()  ?? "",
            'cantidad': double.tryParse(r['cantidad']?.toString() ?? "0") ?? 0,
            'monto':    double.tryParse(r['monto']?.toString()    ?? "0") ?? 0,
          });
        }
      }

      setState(() {
        _loterias     = lots;
        _porMod       = mods;
        _totalGeneral = double.tryParse(data['total_general']?.toString() ?? "0") ?? 0;
        _loading      = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _pickFecha() async {
    final p = await showDatePicker(
      context: context, initialDate: _fecha,
      firstDate: DateTime(2024), lastDate: DateTime.now());
    if (p != null) { setState(() => _fecha = p); _cargar(); }
  }

  @override
  Widget build(BuildContext context) {
    final hasData = _porMod.values.any((v) => v.isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Venta por Lista"),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: Column(children: [
        // Filtros
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            Expanded(child: DropdownButtonFormField<String>(
              value: _loteriaId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(), isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
              items: [
                const DropdownMenuItem(value: "TODAS",      child: Text("Todas")),
                ..._loterias.map((l) => DropdownMenuItem(
                    value: l['id'], child: Text(l['nombre']!))),
                const DropdownMenuItem(value: "SUPER_PALE", child: Text("Super Pale")),
              ],
              onChanged: (v) {
                if (v != null) { setState(() => _loteriaId = v); _cargar(); }
              },
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
        // Contenido
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
            ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
            : !hasData
              ? const Center(child: Text("No hay ventas para esta fecha.",
                  style: TextStyle(color: Colors.grey)))
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    children: [
                      ..._porMod.entries.where((e) => e.value.isNotEmpty).map((e) {
                        final mod   = e.key;
                        final filas = e.value;
                        final total = filas.fold(0.0, (s, f) => s + (f['monto'] as double));
                        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(mod,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                          Table(
                            border: TableBorder.all(color: Colors.grey.shade300),
                            columnWidths: const {
                              0: FlexColumnWidth(2), 1: FlexColumnWidth(2),
                              2: FlexColumnWidth(1), 3: FlexColumnWidth(1.5),
                            },
                            children: [
                              TableRow(
                                decoration: BoxDecoration(color: Colors.grey.shade100),
                                children: ['Lotería','Jugada','Cant','Monto'].map((h) =>
                                  Padding(padding: const EdgeInsets.all(6),
                                    child: Text(h,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center))).toList()),
                              ...filas.map((f) => TableRow(children: [
                                Padding(padding: const EdgeInsets.all(6),
                                  child: Text(f['loteria'], textAlign: TextAlign.center)),
                                Padding(padding: const EdgeInsets.all(6),
                                  child: Text(f['jugada'],  textAlign: TextAlign.center)),
                                Padding(padding: const EdgeInsets.all(6),
                                  child: Text((f['cantidad'] as double).toStringAsFixed(0),
                                    textAlign: TextAlign.center)),
                                Padding(padding: const EdgeInsets.all(6),
                                  child: Text(fmtMonto(f['monto']), textAlign: TextAlign.center)),
                              ])),
                            ],
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text("Total $mod: ${fmtMonto(total)}",
                                  style: const TextStyle(fontWeight: FontWeight.bold)))),
                          const Divider(),
                        ]);
                      }),
                      if (hasData)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text("Total General: ${fmtMonto(_totalGeneral)}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            textAlign: TextAlign.right)),
                    ],
                  ),
                )),
      ]),
    );
  }
}
