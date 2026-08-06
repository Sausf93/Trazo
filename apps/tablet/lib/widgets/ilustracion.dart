import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';

/// Librería de ilustraciones de Trazo.
///
/// Pinta el SVG `assets/ilustraciones/{id}.svg` para un id de objeto del
/// catálogo (fruta, cubierto, dinero, figura, cara…). Los dibujos están
/// pensados para verse GRANDES y reconocibles por personas mayores.
///
/// El resolver de ids ([IlustracionResolver]) normaliza las variantes que
/// llegan del backend (p. ej. `manzana_roja` -> `manzana`) a los nombres de
/// archivo disponibles. Si un id no tiene dibujo, [Ilustracion] pinta un
/// fallback neutro (círculo con la inicial) y NUNCA rompe el render.
class Ilustracion extends StatelessWidget {
  final String id;
  final double size;

  const Ilustracion(this.id, {super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final asset = IlustracionResolver.assetPara(id);
    if (asset == null) {
      return _FallbackInicial(id: id, size: size);
    }
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      // Semántica para lectores de pantalla / accesibilidad.
      semanticsLabel: IlustracionResolver.etiqueta(id),
      placeholderBuilder: (_) => SizedBox(width: size, height: size),
    );
  }
}

/// Fallback cuando no hay dibujo: círculo de marca con la inicial del id.
class _FallbackInicial extends StatelessWidget {
  final String id;
  final double size;

  const _FallbackInicial({required this.id, required this.size});

  @override
  Widget build(BuildContext context) {
    final inicial =
        (id.trim().isEmpty ? '?' : id.trim()[0]).toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: TrazoColors.card,
        border: Border.all(color: TrazoColors.sageDark, width: 2.4),
      ),
      child: Text(
        inicial,
        style: TextStyle(
          fontSize: size * 0.44,
          fontWeight: FontWeight.bold,
          color: TrazoColors.sageDark,
        ),
      ),
    );
  }
}

/// Centraliza el mapa de ids -> archivo de ilustración. Punto único de
/// extensión: para añadir un objeto basta con crear el SVG y (si el id del
/// catálogo difiere del nombre de archivo) registrar un alias aquí.
class IlustracionResolver {
  const IlustracionResolver._();

  static const String _dir = 'assets/ilustraciones/';

  /// Nombres de archivo disponibles (sin extensión). Debe coincidir con los
  /// SVG de `assets/ilustraciones/`.
  static const Set<String> _disponibles = {
    // Frutas
    'manzana', 'manzana_verde', 'pera', 'naranja', 'melocoton', 'uvas',
    'sandia', 'melon', 'limon', 'fresa',
    // Verdura
    'tomate', 'zanahoria',
    // Mesa / cubiertos
    'plato', 'cuchara', 'tenedor', 'cuchillo', 'vaso', 'taza', 'bol',
    // Cocina
    'sarten', 'olla', 'botella', 'batidora', 'nevera',
    // Dinero
    'moneda_1c', 'moneda_2c', 'moneda_5c', 'moneda_10c', 'moneda_20c',
    'moneda_50c', 'moneda_1e', 'moneda_2e',
    'billete_5', 'billete_10', 'billete_20', 'billete_50', 'billete_100',
    // Figuras
    'estrella', 'corazon', 'circulo', 'cuadrado', 'triangulo', 'luna', 'sol',
    'flor',
    // Caras / emociones
    'cara_alegria', 'cara_tristeza', 'cara_sorpresa', 'cara_enfado',
  };

  /// Alias: id del catálogo -> nombre de archivo canónico. Amplía aquí libremente.
  static const Map<String, String> _alias = {
    // Manzanas
    'manzana_roja': 'manzana',
    'manzana_amarilla': 'manzana',
    // Uva(s)
    'uva': 'uvas',
    'racimo': 'uvas',
    // Naranja / cítricos
    'mandarina': 'naranja',
    'lima': 'limon',
    // Verdura / etiquetas de compra
    'manzanas': 'manzana',
    'lechuga': 'flor', // hoja verde reconocible como fallback vegetal
    // Cubiertos y mesa
    'cuchara_sopera': 'cuchara',
    'tenedor_mesa': 'tenedor',
    'copa': 'vaso',
    'taza_cafe': 'taza',
    'cuenco': 'bol',
    'servilleta': 'cuadrado',
    // Cocina / despensa
    'cazuela': 'olla',
    'cacerola': 'olla',
    'aceite': 'botella',
    'agua': 'botella',
    'vino': 'botella',
    'leche': 'botella',
    'frigorifico': 'nevera',
    // Figuras (piezas geométricas de arrastrar/memoria)
    'cuadro': 'cuadrado',
    'redondo': 'circulo',
    'redonda': 'circulo',
    'circunferencia': 'circulo',
    'estrellita': 'estrella',
    'margarita': 'flor',
    'rosa': 'flor',
    'girasol': 'sol',
    // Fichas / botones de conteo -> monedas o figuras reconocibles
    'ficha_roja': 'circulo',
    'ficha_azul': 'circulo',
    'ficha_verde': 'circulo',
    'boton_grande': 'circulo',
    'boton_pequeno': 'circulo',
    'boton': 'circulo',
    'moneda': 'moneda_1e',
    'moneda_dorada': 'moneda_1e',
    'moneda_plateada': 'moneda_2e',
    // Flores de colores (conteo) -> flor
    'flor_roja': 'flor',
    'flor_azul': 'flor',
    'flor_blanca': 'flor',
    'flor_amarilla': 'flor',
    // Caras / emociones (variantes)
    'feliz': 'cara_alegria',
    'contento': 'cara_alegria',
    'alegre': 'cara_alegria',
    'triste': 'cara_tristeza',
    'sorprendido': 'cara_sorpresa',
    'asombro': 'cara_sorpresa',
    'enfadado': 'cara_enfado',
    'enfado': 'cara_enfado',
  };

  /// Normaliza un id a minúsculas, sin espacios ni acentos, con guion_bajo.
  static String normaliza(String raw) {
    var s = raw.trim().toLowerCase();
    const acentos = {
      'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
      'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
      'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
      'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
      'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
      'ñ': 'n',
    };
    acentos.forEach((k, v) => s = s.replaceAll(k, v));
    s = s.replaceAll(RegExp(r'[\s\-]+'), '_');
    s = s.replaceAll(RegExp(r'[^a-z0-9_]'), '');
    return s;
  }

  /// Nombre de archivo canónico (sin ruta ni extensión) o `null` si no existe.
  static String? _canonico(String raw) {
    final s = normaliza(raw);
    if (s.isEmpty) return null;
    if (_disponibles.contains(s)) return s;
    final al = _alias[s];
    if (al != null && _disponibles.contains(al)) return al;
    return null;
  }

  /// Ruta del asset SVG para un id, o `null` si no hay dibujo (usar fallback).
  static String? assetPara(String raw) {
    final c = _canonico(raw);
    return c == null ? null : '$_dir$c.svg';
  }

  /// `true` si existe una ilustración concreta para el id.
  static bool tiene(String raw) => _canonico(raw) != null;

  /// Etiqueta legible para accesibilidad (id con espacios).
  static String etiqueta(String raw) => raw.replaceAll('_', ' ');

  /// Devuelve el id de ilustración de dinero para una denominación en céntimos.
  /// 1c..50c -> monedas; 100/200 -> monedas de euro; 500..10000 -> billetes.
  static String? dineroPorCentimos(int valorC) {
    const mapa = {
      1: 'moneda_1c', 2: 'moneda_2c', 5: 'moneda_5c',
      10: 'moneda_10c', 20: 'moneda_20c', 50: 'moneda_50c',
      100: 'moneda_1e', 200: 'moneda_2e',
      500: 'billete_5', 1000: 'billete_10', 2000: 'billete_20',
      5000: 'billete_50', 10000: 'billete_100',
    };
    return mapa[valorC];
  }
}
