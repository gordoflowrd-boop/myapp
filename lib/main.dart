import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const SuperBettApp());
}

class SuperBettApp extends StatelessWidget {
  const SuperBettApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SuperBett POS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

// --- 1. PANTALLA DE LOGIN ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  String _mensaje = "Ingrese usuario y PIN";
  bool _isLoading = false;

  final String apiUrl = "https://superbett-api-production.up.railway.app";

  Future<void> _login() async {
    final String username = _userController.text.trim().toLowerCase();
    final String pin = _pinController.text.trim();

    if (username.isEmpty || pin.isEmpty) {
      setState(() => _mensaje = "Ingrese usuario y PIN");
      return;
    }

    setState(() {
      _isLoading = true;
      _mensaje = "Validando...";
    });

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/api/auth/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username, "password": pin}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                MenuPage(userData: data['usuario'], token: data['token']),
          ),
        );
      } else {
        setState(() {
          _mensaje = data['error'] ?? "Credenciales inválidas";
          _pinController.clear();
        });
      }
    } catch (e) {
      setState(() => _mensaje = "Error de conexión");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              const Icon(Icons.account_balance_wallet, size: 80, color: Colors.blueGrey),
              const SizedBox(height: 10),
              const Text("SUPERBETT POS",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(_mensaje, style: TextStyle(color: Colors.blueGrey.shade600)),
              const SizedBox(height: 30),
              TextField(
                controller: _userController,
                decoration: const InputDecoration(
                    labelText: "Usuario", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: "PIN", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 25),
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey,
                            foregroundColor: Colors.white),
                        child: const Text("INGRESAR"),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 2. PANTALLA DE MENÚ PRINCIPAL ---
class MenuPage extends StatelessWidget {
  final Map<String, dynamic> userData;
  final String token;
  const MenuPage({super.key, required this.userData, required this.token});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> menuItems = [
      {'title': 'Venta', 'icon': Icons.shopping_cart},
      {'title': 'Lista de Ventas', 'icon': Icons.list_alt},
      {'title': 'Lista de Tickets', 'icon': Icons.confirmation_number},
      {'title': 'Reportes', 'icon': Icons.bar_chart},
      {'title': 'Anular Ticket', 'icon': Icons.delete_forever},
      {'title': 'Pago de Ticket', 'icon': Icons.attach_money},
      {'title': 'Configuración', 'icon': Icons.settings},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Menú Principal"),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage()),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blueGrey.shade50,
            width: double.infinity,
            child: Text(
              "Bienvenido: ${userData['nombre'] ?? userData['username']} (${userData['rol']})",
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.blueGrey),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                return Card(
                  child: ListTile(
                    leading:
                        Icon(menuItems[index]['icon'], color: Colors.blueGrey),
                    title: Text(menuItems[index]['title']),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    // ✅ CORREGIDO: onPressed → onTap
                    onTap: () {
                      if (menuItems[index]['title'] == 'Venta') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                VentaPage(userData: userData, token: token),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- 3. PANTALLA DE VENTA ---
class VentaPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String token;
  const VentaPage({super.key, required this.userData, required this.token});

  @override
  State<VentaPage> createState() => _VentaPageState();
}

class _VentaPageState extends State<VentaPage> {
  final String apiUrl = "https://superbett-api-production.up.railway.app/api";
  final TextEditingController _numController = TextEditingController();
  final TextEditingController _cantController = TextEditingController();

  List<Map<String, dynamic>> _listaJugadas = [];
  List<dynamic> _jornadas = [];
  String? _selectedJornadaId;
  bool _isLoading = true;
  bool _isSending = false;
  double _totalTicket = 0.0;

  @override
  void initState() {
    super.initState();
    _cargarLoterias();
  }

  Future<void> _cargarLoterias() async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/jornadas/abiertas'),
        headers: {"Authorization": "Bearer ${widget.token}"},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _jornadas = data['jornadas'] ?? [];
          // ✅ CORREGIDO: if con llaves {}
          if (_jornadas.isNotEmpty) {
            _selectedJornadaId = _jornadas[0]['jornada_id'].toString();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  void _agregarJugada() {
    String num = _numController.text.trim();
    int? cant = int.tryParse(_cantController.text.trim());

    if (num.isEmpty || cant == null || cant <= 0) return;

    String mod = "";
    // ✅ CORREGIDO: if/else con llaves {} (líneas 253-255)
    if (num.length == 2) {
      mod = "Q";
    } else if (num.length == 4) {
      mod = "P";
    } else if (num.length == 6) {
      mod = "T";
    } else {
      return;
    }

    setState(() {
      double monto = cant.toDouble();
      _listaJugadas.add({
        "modalidad": mod,
        "numeros": num,
        "cantidad": cant,
        "monto": monto,
      });
      _totalTicket += monto;
      _numController.clear();
      _cantController.clear();
    });
  }

  Future<void> _venderTicket() async {
    if (_listaJugadas.isEmpty || _selectedJornadaId == null) return;

    setState(() => _isSending = true);

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/tickets'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.token}",
        },
        body: jsonEncode({
          "jornada_id": _selectedJornadaId,
          "jugadas": _listaJugadas,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || data['estado'] == 'ok') {
        _mostrarExito(data['numero_ticket'].toString());
        setState(() {
          _listaJugadas.clear();
          _totalTicket = 0;
        });
      } else {
        _mostrarError(data['mensaje'] ?? "Error al vender");
      }
    } catch (e) {
      _mostrarError("Error de conexión al vender");
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _mostrarExito(String num) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¡Venta Exitosa!"),
        content: Text("Ticket #$num generado correctamente."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
        ],
      ),
    );
  }

  void _mostrarError(String msj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msj), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Venta SuperBett"),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  color: Colors.blueGrey.shade700,
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    "${widget.userData['nombre']} — ${widget.userData['username']}",
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: _selectedJornadaId,
                              items: _jornadas
                                  .map((j) => DropdownMenuItem(
                                        value: j['jornada_id'].toString(),
                                        child: Text(j['nombre'],
                                            style: const TextStyle(fontSize: 12)),
                                      ))
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => _selectedJornadaId = val),
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding:
                                    EdgeInsets.symmetric(horizontal: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "\$${_totalTicket.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  color: Colors.lime,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _numController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  hintText: "Jugada",
                                  border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: TextField(
                              controller: _cantController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  hintText: "Cant",
                                  border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 5),
                          ElevatedButton(
                            onPressed: _agregarJugada,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(18),
                            ),
                            child: const Text("ADD"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(10),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1.4,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _listaJugadas.length,
                    itemBuilder: (context, index) {
                      final item = _listaJugadas[index];
                      return Card(
                        elevation: 3,
                        child: Stack(
                          children: [
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "${item['modalidad']} ${item['numeros']}",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    "\$${(item['monto'] as double).toStringAsFixed(2)}",
                                    style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              right: -10,
                              top: -10,
                              child: IconButton(
                                icon: const Icon(Icons.cancel,
                                    color: Colors.red, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _totalTicket -=
                                        _listaJugadas[index]['monto'];
                                    _listaJugadas.removeAt(index);
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSending ? null : _venderTicket,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(15),
                          ),
                          child: _isSending
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text("VENDER",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => setState(() {
                            _listaJugadas.clear();
                            _totalTicket = 0;
                          }),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(15),
                          ),
                          child: const Text("LIMPIAR"),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

