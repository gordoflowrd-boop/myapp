import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'venta_page.dart';
import 'lista_ventas_page.dart';
import 'lista_tickets_page.dart';
import 'reportes_page.dart';
import 'anular_ticket_page.dart';
import 'pagar_ticket_page.dart';
import 'configuracion_page.dart';

class MenuPage extends StatelessWidget {
  final Map<String, dynamic> userData;
  final String token;
  const MenuPage({super.key, required this.userData, required this.token});

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    if (!context.mounted) return;
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const LoginPage()));
  }

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
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.all(14),
          color: Colors.blueGrey.shade50,
          width: double.infinity,
          child: Text(
            "Bienvenido: ${userData['nombre'] ?? userData['username']} (${userData['rol']})",
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: items.length,
            itemBuilder: (ctx, i) => Card(
              child: ListTile(
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
              ),
            ),
          ),
        ),
      ]),
    );
  }
}