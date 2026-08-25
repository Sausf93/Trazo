import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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
  Map<String, Veredicto> _cache = {};
  bool _cargado = false;

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
