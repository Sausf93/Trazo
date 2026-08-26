import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

/// Veredicto de la especialista sobre una actividad en el BANCO DE PRUEBAS:
/// válida o "a revisar", con una nota opcional. Se guarda EN EL DISPOSITIVO
/// (shared_preferences), no toca el backend ni datos reales. Sirve para que la
/// pareja de Saulo (especialista) recorra todas y deje su criterio, y luego se
/// copie la lista de las que hay que arreglar.
class Veredicto {
  final String estado; // 'valida' | 'revisar'
  final String nota;
  const Veredicto(this.estado, this.nota);

  Map<String, dynamic> toJson() => {'v': estado, 'n': nota};
  factory Veredicto.fromJson(Map<String, dynamic> j) =>
      Veredicto((j['v'] ?? '').toString(), (j['n'] ?? '').toString());
}

class BancoVeredictos {
  BancoVeredictos._();
  static final BancoVeredictos instance = BancoVeredictos._();

  static const _clave = 'trazo_banco_veredictos_v1';
  static const _claveNombre = 'trazo_banco_nombre';
  // Token compartido con el backend (mismo valor en app/routers/banco.py). Las
  // marcas no tienen datos de personas: solo actividad + veredicto + nota.
  static const _tokenBanco = 'trazo-lab-2026';
  Map<String, Veredicto> _cache = {};
  bool _cargado = false;

  /// Quién está marcando (Saulo, Laura…). Se guarda una vez en el dispositivo y
  /// viaja con cada marca para que el equipo sepa quién dijo qué.
  Future<String> nombreMarcador() async {
    try {
      final sp = await SharedPreferences.getInstance();
      return sp.getString(_claveNombre) ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> fijarNombre(String nombre) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_claveNombre, nombre.trim());
    } catch (_) {}
  }

  /// Envía la marca al servidor (best-effort). Así Saulo y Laura marcan desde sus
  /// dispositivos y todo se consolida en un solo sitio que el equipo revisa.
  Future<void> _sincronizar(String nombre, String estado, String nota) async {
    try {
      final quien = await nombreMarcador();
      final base = Uri.parse(Config.apiUrl);
      final url = Uri(
          scheme: base.scheme,
          host: base.host,
          port: base.hasPort ? base.port : null,
          path: '/banco/veredictos');
      await http
          .post(url,
              headers: {
                'Content-Type': 'application/json',
                'X-Lab-Token': _tokenBanco,
              },
              body: jsonEncode({
                'actividad': nombre,
                'estado': estado,
                'nota': nota,
                'marcado_por': quien,
              }))
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Best-effort: si no hay red, la marca queda igualmente en el dispositivo.
    }
  }

  Future<void> _cargar() async {
    if (_cargado) return;
    _cargado = true;
    try {
      final sp = await SharedPreferences.getInstance();
      final txt = sp.getString(_clave);
      if (txt != null && txt.isNotEmpty) {
        final m = jsonDecode(txt) as Map<String, dynamic>;
        _cache = {
          for (final e in m.entries)
            e.key:
                Veredicto.fromJson(Map<String, dynamic>.from(e.value as Map)),
        };
      }
    } catch (_) {
      _cache = {};
    }
  }

  Future<Map<String, Veredicto>> todos() async {
    await _cargar();
    return Map<String, Veredicto>.from(_cache);
  }

  Future<Veredicto?> para(String nombre) async {
    await _cargar();
    return _cache[nombre];
  }

  Future<void> guardar(String nombre, String estado, String nota) async {
    await _cargar();
    _cache[nombre] = Veredicto(estado, nota);
    await _persistir();
    // Envía al servidor en segundo plano (solo las marcas reales, no distrae).
    if (estado == 'revisar' || estado == 'otro_grupo') {
      unawaited(_sincronizar(nombre, estado, nota));
    }
  }

  Future<void> borrar(String nombre) async {
    await _cargar();
    _cache.remove(nombre);
    await _persistir();
  }

  Future<void> _persistir() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(
          _clave,
          jsonEncode(
              {for (final e in _cache.entries) e.key: e.value.toJson()}));
    } catch (_) {/* best-effort */}
  }
}
