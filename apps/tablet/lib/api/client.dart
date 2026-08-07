import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models.dart';

/// Cliente HTTP hacia la API de Trazo. Guarda el token en SharedPreferences.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  /// Se invoca cuando la API responde 401 (token caducado/ inválido) para que
  /// la app vuelva al login. Lo configura `main()`.
  static void Function()? onNoAutorizado;

  String? _token;
  String? centroId;
  String? rol;
  String? nombre;

  /// Tiempo máximo de espera de cada petición. En el centro el WiFi puede ser
  /// inestable; sin esto una llamada colgada dejaría al mayor atrapado en
  /// "Preparando…" para siempre. Al vencer, lanza ApiException (rama de error
  /// con botón "Reintentar").
  static const Duration _kTimeout = Duration(seconds: 12);

  Never _timeoutErr() =>
      throw ApiException('No hay conexión con el servidor. Inténtalo de nuevo.');

  Uri _u(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse(Config.apiUrl);
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: path,
      queryParameters: query?.map((k, v) => MapEntry(k, v?.toString())),
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
    nombre = prefs.getString('nombre');
  }

  bool get autenticado => _token != null;

  /// Login (form-urlencoded, como espera OAuth2PasswordRequestForm).
  Future<void> login(String email, String password) async {
    final resp = await http.post(
      _u('/auth/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': email, 'password': password},
    ).timeout(_kTimeout, onTimeout: _timeoutErr);
    if (resp.statusCode != 200) {
      throw ApiException('Login fallido (${resp.statusCode})');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    _token = data['access_token'] as String;
    centroId = data['centro_id'] as String?;
    rol = data['rol'] as String?;
    nombre = data['nombre'] as String?;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', _token!);
    if (centroId != null) await prefs.setString('centro_id', centroId!);
    if (rol != null) await prefs.setString('rol', rol!);
    if (nombre != null) await prefs.setString('nombre', nombre!);
  }

  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('centro_id');
    await prefs.remove('rol');
    await prefs.remove('nombre');
  }

  // --- Participantes del centro -------------------------------------------

  Future<List<UsuarioFinal>> usuariosDelCentro() async {
    final resp =
        await http.get(_u('/centros/$centroId/usuarios'), headers: _headers).timeout(_kTimeout, onTimeout: _timeoutErr);
    _check(resp);
    final list = jsonDecode(resp.body) as List;
    return list
        .map((e) => UsuarioFinal.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // --- Ejercicios ----------------------------------------------------------

  Future<List<Ejercicio>> ejercicios({String? bloque}) async {
    final resp = await http.get(
        _u('/ejercicios', {if (bloque != null) 'bloque': bloque}),
        headers: _headers).timeout(_kTimeout, onTimeout: _timeoutErr);
    _check(resp);
    final list = jsonDecode(resp.body) as List;
    return list
        .map((e) => Ejercicio.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Instancia> generarInstancia(String ejercicioId,
      {String? usuarioFinalId, String? nivel}) async {
    final resp = await http.get(
      _u('/ejercicios/$ejercicioId/instancia', {
        if (usuarioFinalId != null) 'usuario_final_id': usuarioFinalId,
        if (nivel != null) 'nivel': nivel,
      }),
      headers: _headers,
    ).timeout(_kTimeout, onTimeout: _timeoutErr);
    _check(resp);
    return Instancia.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  // --- Sesiones ------------------------------------------------------------

  /// Crea una sesión (sala) y devuelve su id.
  ///
  /// [configs] = config por participante para ESTA sesión:
  /// `[{usuario_final_id, nivel?, lineas:[{bloque, n}]}]`. Un participante con
  /// config saca su cola de ahí; si no, de su plan.
  Future<String> crearSesion({
    required String tipo, // "grupo" | "individual"
    required String nombre,
    String? modo,
    String? ejercicioCompartidoId,
    List<String> participantes = const [],
    List<Map<String, dynamic>> configs = const [],
    bool programar = false,
    String? programadaPara, // 'YYYY-MM-DD'
  }) async {
    final resp = await http.post(
      _u('/sesiones'),
      headers: _headers,
      body: jsonEncode({
        'tipo': tipo,
        'nombre': nombre,
        if (modo != null) 'modo': modo,
        if (ejercicioCompartidoId != null)
          'ejercicio_compartido_id': ejercicioCompartidoId,
        'participantes': participantes,
        if (configs.isNotEmpty) 'configs': configs,
        if (programar) 'programar': true,
        if (programadaPara != null) 'programada_para': programadaPara,
      }),
    ).timeout(_kTimeout, onTimeout: _timeoutErr);
    _check(resp);
    return (jsonDecode(resp.body) as Map<String, dynamic>)['id'] as String;
  }

  /// Plan de trabajo de la persona (`GET /usuarios/{id}/plan`).
  Future<List<PlanLinea>> planUsuario(String usuarioId) async {
    final resp =
        await http.get(_u('/usuarios/$usuarioId/plan'), headers: _headers).timeout(_kTimeout, onTimeout: _timeoutErr);
    _check(resp);
    final data = jsonDecode(resp.body);
    // El endpoint puede devolver una lista o `{lineas: [...]}`.
    final list = data is List ? data : ((data['lineas'] ?? []) as List);
    return list
        .map((e) => PlanLinea.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Estado de la sesión activa del centro (para el kiosco del participante).
  Future<SesionActiva> sesionActiva() async {
    final resp = await http.get(
        _u('/sesiones/activa', {'centro_id': centroId}),
        headers: _headers).timeout(_kTimeout, onTimeout: _timeoutErr);
    _check(resp);
    return SesionActiva.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  /// Salas dejadas PREPARADAS (programadas, sin abrir) del centro.
  Future<List<SesionProgramada>> sesionesProgramadas() async {
    final resp = await http.get(
        _u('/sesiones/programadas', {'centro_id': centroId}),
        headers: _headers).timeout(_kTimeout, onTimeout: _timeoutErr);
    _check(resp);
    final list = jsonDecode(resp.body) as List;
    return list
        .map((e) => SesionProgramada.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Abre una sesión programada: pasa a estar "en vivo" para los kioscos.
  Future<void> abrirSesion(String sesionId) async {
    final resp = await http
        .patch(_u('/sesiones/$sesionId/abrir'), headers: _headers)
        .timeout(_kTimeout, onTimeout: _timeoutErr);
    _check(resp);
  }

  Future<void> iniciarSesion(String sesionId) async {
    final resp =
        await http.patch(_u('/sesiones/$sesionId/iniciar'), headers: _headers).timeout(_kTimeout, onTimeout: _timeoutErr);
    _check(resp);
  }

  Future<void> cerrarSesion(String sesionId) async {
    final resp =
        await http.patch(_u('/sesiones/$sesionId/cerrar'), headers: _headers).timeout(_kTimeout, onTimeout: _timeoutErr);
    _check(resp);
  }

  /// Monitor en vivo de la sesión.
  Future<List<FichaLive>> sesionLive(String sesionId) async {
    final resp =
        await http.get(_u('/sesiones/$sesionId/live'), headers: _headers).timeout(_kTimeout, onTimeout: _timeoutErr);
    _check(resp);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final fichas = (data['fichas'] ?? []) as List;
    return fichas
        .map((e) => FichaLive.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // --- Cola del participante ----------------------------------------------

  Future<List<ColaItem>> colaUsuario(String usuarioId, String sesionId) async {
    final resp = await http.get(
        _u('/usuarios/$usuarioId/cola', {'sesion_id': sesionId}),
        headers: _headers).timeout(_kTimeout, onTimeout: _timeoutErr);
    _check(resp);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final items = (data['items'] ?? []) as List;
    return items
        .map((e) => ColaItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // --- Estado / rondas del participante -----------------------------------

  /// Estado del participante dentro de la sesión: `{iniciada, ronda, terminado}`.
  Future<EstadoParticipante> estadoParticipante(
      String sesionId, String usuarioId) async {
    final resp = await http.get(
        _u('/sesiones/$sesionId/participantes/$usuarioId/estado'),
        headers: _headers).timeout(_kTimeout, onTimeout: _timeoutErr);
    _check(resp);
    return EstadoParticipante.fromJson(
        jsonDecode(resp.body) as Map<String, dynamic>);
  }

  /// La tablet avisa de que el participante terminó su tanda. Devuelve el estado
  /// (con la `ronda` actual, para detectar luego una nueva tanda de la maestra).
  Future<EstadoParticipante> marcarTerminadoParticipante(
      String sesionId, String usuarioId) async {
    final resp = await http.post(
        _u('/sesiones/$sesionId/participantes/$usuarioId/terminado'),
        headers: _headers).timeout(_kTimeout, onTimeout: _timeoutErr);
    _check(resp);
    return EstadoParticipante.fromJson(
        jsonDecode(resp.body) as Map<String, dynamic>);
  }

  /// La maestra manda OTRA tanda a quien terminó (sube `ronda`, reinicia
  /// `terminado`). Body opcional `{nivel?, lineas:[{bloque,n}]}`; sin body
  /// repite la config/plan del participante.
  Future<void> enviarMas(
    String sesionId,
    String usuarioId, {
    String? nivel,
    List<Map<String, dynamic>>? lineas,
  }) async {
    final body = <String, dynamic>{
      if (nivel != null) 'nivel': nivel,
      if (lineas != null) 'lineas': lineas,
    };
    final resp = await http.patch(
      _u('/sesiones/$sesionId/participantes/$usuarioId/mas'),
      headers: _headers,
      body: jsonEncode(body),
    ).timeout(_kTimeout, onTimeout: _timeoutErr);
    _check(resp);
  }

  // --- Intentos ------------------------------------------------------------

  /// Registra un intento. Devuelve el id del intento creado (o null si falló).
  Future<String?> registrarIntento(Intento intento) async {
    final resp = await http.post(
      _u('/sesiones/${intento.sesionId}/intentos'),
      headers: _headers,
      body: jsonEncode(intento.toJson()),
    ).timeout(_kTimeout, onTimeout: _timeoutErr);
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      try {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return (data['id'] ?? intento.id) as String;
      } catch (_) {
        return intento.id;
      }
    }
    return null;
  }

  /// Marca un intento como "con_ayuda" (control exclusivo de la maestra).
  Future<void> marcarEstadoIntento(String intentoId, String estado) async {
    final resp = await http.patch(
      _u('/intentos/$intentoId/estado'),
      headers: _headers,
      body: jsonEncode({'estado': estado}),
    ).timeout(_kTimeout, onTimeout: _timeoutErr);
    _check(resp);
  }

  void _check(http.Response resp) {
    if (resp.statusCode == 401) {
      // Token caducado o inválido: cerrar sesión y volver al login.
      _token = null;
      SharedPreferences.getInstance().then((p) {
        p.remove('token');
        p.remove('centro_id');
        p.remove('rol');
        p.remove('nombre');
      });
      onNoAutorizado?.call();
      throw ApiException('Sesión caducada. Vuelve a iniciar sesión.');
    }
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
