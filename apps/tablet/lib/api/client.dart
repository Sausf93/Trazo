import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models.dart';

/// Cliente HTTP hacia la API de Trazo. Guarda el token en SharedPreferences.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String? _token;
  String? centroId;
  String? rol;

  Uri _u(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse(Config.apiUrl);
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: path,
      queryParameters:
          query?.map((k, v) => MapEntry(k, v?.toString())),
    );
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<void> cargarSesionGuardada() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    centroId = prefs.getString('centro_id');
    rol = prefs.getString('rol');
  }

  bool get autenticado => _token != null;

  /// Login (form-urlencoded, como espera OAuth2PasswordRequestForm).
  Future<void> login(String email, String password) async {
    final resp = await http.post(
      _u('/auth/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': email, 'password': password},
    );
    if (resp.statusCode != 200) {
      throw ApiException('Login fallido (${resp.statusCode})');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    _token = data['access_token'] as String;
    centroId = data['centro_id'] as String?;
    rol = data['rol'] as String?;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', _token!);
    if (centroId != null) await prefs.setString('centro_id', centroId!);
    if (rol != null) await prefs.setString('rol', rol!);
  }

  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  Future<List<UsuarioFinal>> usuariosDelCentro() async {
    final resp = await http.get(_u('/centros/$centroId/usuarios'),
        headers: _headers);
    _check(resp);
    final list = jsonDecode(resp.body) as List;
    return list
        .map((e) => UsuarioFinal.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Ejercicio>> ejercicios({String? bloque}) async {
    final resp = await http.get(
        _u('/ejercicios', {if (bloque != null) 'bloque': bloque}),
        headers: _headers);
    _check(resp);
    final list = jsonDecode(resp.body) as List;
    return list
        .map((e) => Ejercicio.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Instancia> generarInstancia(String ejercicioId,
      {String? usuarioFinalId}) async {
    final resp = await http.get(
      _u('/ejercicios/$ejercicioId/instancia',
          {if (usuarioFinalId != null) 'usuario_final_id': usuarioFinalId}),
      headers: _headers,
    );
    _check(resp);
    return Instancia.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  /// Crea una sesión y devuelve su id.
  Future<String> crearSesion(
      {String tipo = 'individual', List<String> participantes = const []}) async {
    final resp = await http.post(
      _u('/sesiones'),
      headers: _headers,
      body: jsonEncode({'tipo': tipo, 'participantes': participantes}),
    );
    _check(resp);
    return (jsonDecode(resp.body) as Map<String, dynamic>)['id'] as String;
  }

  /// Registra un intento. Devuelve true si el backend lo aceptó.
  Future<bool> registrarIntento(Intento intento) async {
    final resp = await http.post(
      _u('/sesiones/${intento.sesionId}/intentos'),
      headers: _headers,
      body: jsonEncode(intento.toJson()),
    );
    return resp.statusCode == 200 || resp.statusCode == 201;
  }

  void _check(http.Response resp) {
    if (resp.statusCode >= 400) {
      throw ApiException('Error ${resp.statusCode}: ${resp.body}');
    }
  }
}

class ApiException implements Exception {
  final String mensaje;
  ApiException(this.mensaje);
  @override
  String toString() => mensaje;
}
