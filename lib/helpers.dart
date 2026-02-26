import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String kApi = "https://superbett-api-production.up.railway.app/api";

/// Petición autenticada a la API
Future<Map<String, dynamic>> apiFetch(
  String path,
  String token, {
  String method = "GET",
  Map<String, dynamic>? body,
}) async {
  final uri = Uri.parse('$kApi$path');
  final headers = {
    "Content-Type": "application/json",
    "Authorization": "Bearer $token",
  };
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

/// Formatea un número como moneda
String fmtMonto(double v) => "\$${v.toStringAsFixed(2)}";

/// Muestra un SnackBar
void snack(BuildContext ctx, String msg, {Color bg = Colors.blueGrey}) {
  ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: bg),
  );
}
