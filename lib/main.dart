import 'package:flutter/material.dart';

void main() {
  runApp(const SuperBettApp());
}

class SuperBettApp extends StatelessWidget {
  const SuperBettApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Quita la banda roja de "Debug"
      title: 'SuperBett Admin',
      theme: ThemeData(
        // Usamos un esquema de colores profesional
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView( // Evita errores si el teclado tapa la pantalla
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icono o Logo provisional
              const Icon(Icons.account_balance_wallet, size: 80, color: Colors.blueGrey),
              const SizedBox(height: 20),
              const Text(
                "SUPERBETT",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              const Text("Panel de Administración"),
              const SizedBox(height: 40),
              
              // Campo de Usuario
              TextField(
                decoration: InputDecoration(
                  labelText: "Usuario de Banca",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 20),
              
              // Campo de Contraseña
              TextField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Contraseña",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 30),
              
              // Botón de Entrar
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    // Aquí irá la lógica para conectar con tu servidor
                    print("Intentando entrar a SuperBett...");
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("INICIAR SESIÓN"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
