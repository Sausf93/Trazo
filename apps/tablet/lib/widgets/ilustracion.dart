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
    // 1) Foto real, si existe: máxima reconocibilidad para personas mayores.
    final foto = IlustracionResolver.fotoPara(id);
    if (foto != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          foto,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _FallbackInicial(id: id, size: size),
        ),
      );
    }
    // 2) Dibujo SVG de la librería.
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
    'sandia', 'melon', 'limon', 'fresa', 'platano', 'cereza',
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
    // Comida (ampliación)
    'pan', 'queso', 'huevo', 'leche', 'pescado', 'pollo', 'patata', 'cebolla',
    'lechuga', 'pimiento', 'tarta', 'galleta', 'jamon', 'cafe',
    // Animales
    'perro', 'gato', 'vaca', 'caballo', 'gallina', 'cerdo', 'oveja', 'pajaro',
    'pez', 'conejo', 'raton',
    // Ropa
    'camisa', 'pantalon', 'calcetin', 'zapato', 'chaqueta', 'gorro', 'bufanda',
    'gafas', 'paraguas', 'vestido', 'guantes',
    // Casa / muebles / objetos
    'silla', 'mesa', 'cama', 'sofa', 'lampara', 'puerta', 'ventana', 'telefono',
    'television', 'llave', 'libro', 'lapiz', 'tijeras', 'peine',
    'cepillo_dientes', 'jabon', 'toalla', 'espejo', 'casa', 'reloj',
    // Herramientas
    'martillo', 'destornillador', 'llave_inglesa', 'sierra', 'pincel',
    // Vehículos
    'coche', 'autobus', 'bicicleta', 'tren', 'avion', 'barco', 'moto', 'camion',
    // Naturaleza
    'nube', 'arbol', 'montana', 'hoja',
  };

  /// Alias: id del catálogo -> nombre de archivo canónico. Amplía aquí libremente.
  static const Map<String, String> _alias = {
    // Manzanas
    'manzana_roja': 'manzana',
    'manzana_amarilla': 'manzana',
    // Uva(s)
    'uva': 'uvas',
    'racimo': 'uvas',
    // Plátano
    'banana': 'platano',
    // Naranja / cítricos
    'mandarina': 'naranja',
    'lima': 'limon',
    // Verdura / etiquetas de compra
    'manzanas': 'manzana',
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
    'frigorifico': 'nevera',
    // Figuras (piezas geométricas de arrastrar/memoria)
    'cuadro': 'cuadrado',
    'redondo': 'circulo',
    'redonda': 'circulo',
    'circunferencia': 'circulo',
    'estrellita': 'estrella',
    'margarita': 'flor',
    'rosa': 'flor',
    'clavel': 'flor',
    'geranio': 'flor',
    'tulipan': 'flor',
    'lirio': 'flor',
    'amapola': 'flor',
    'planta': 'flor',
    'maceta': 'flor',
    'girasol': 'sol',
    // Casa / reloj (variantes)
    'casas': 'casa',
    'hogar': 'casa',
    'vivienda': 'casa',
    'chalet': 'casa',
    'relojes': 'reloj',
    'reloj_pared': 'reloj',
    'despertador': 'reloj',
    'cafe_leche': 'cafe',
    'cafe_con_leche': 'cafe',
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
    // Comida (variantes)
    'huevos': 'huevo',
    'huevo_frito': 'huevo',
    'queso_cuna': 'queso',
    'barra_pan': 'pan',
    'barra_de_pan': 'pan',
    'pan_molde': 'pan',
    'leche_carton': 'leche',
    'carton_leche': 'leche',
    'brik_leche': 'leche',
    'pescado_frito': 'pescado',
    'muslo_pollo': 'pollo',
    'muslo_de_pollo': 'pollo',
    'patatas': 'patata',
    'papa': 'patata',
    'papas': 'patata',
    'cebollas': 'cebolla',
    'ensalada': 'lechuga',
    'pimiento_rojo': 'pimiento',
    'pimiento_verde': 'pimiento',
    'pastel': 'tarta',
    'tarta_cumpleanos': 'tarta',
    'porcion_tarta': 'tarta',
    'galletas': 'galleta',
    'jamon_serrano': 'jamon',
    'pata_jamon': 'jamon',
    'cafe_taza': 'cafe',
    'taza_de_cafe': 'cafe',
    // Animales (variantes)
    'perrito': 'perro',
    'cachorro': 'perro',
    'can': 'perro',
    'gatito': 'gato',
    'minino': 'gato',
    'toro': 'vaca',
    'ternera': 'vaca',
    'yegua': 'caballo',
    'poni': 'caballo',
    'pony': 'caballo',
    'gallo': 'gallina',
    'pollito': 'gallina',
    'cochino': 'cerdo',
    'chancho': 'cerdo',
    'puerco': 'cerdo',
    'marrano': 'cerdo',
    'cordero': 'oveja',
    'borrego': 'oveja',
    'pajarito': 'pajaro',
    'ave': 'pajaro',
    'pajaro_azul': 'pajaro',
    'pescadito': 'pez',
    'pececito': 'pez',
    'pez_naranja': 'pez',
    'conejito': 'conejo',
    'ratoncito': 'raton',
    'raton_gris': 'raton',
    // Ropa (variantes)
    'camiseta': 'camisa',
    'blusa': 'camisa',
    'pantalones': 'pantalon',
    'vaqueros': 'pantalon',
    'jeans': 'pantalon',
    'calcetines': 'calcetin',
    'media': 'calcetin',
    'medias': 'calcetin',
    'zapatos': 'zapato',
    'zapatilla': 'zapato',
    'zapatillas': 'zapato',
    'bota': 'zapato',
    'botas': 'zapato',
    'abrigo': 'chaqueta',
    'cazadora': 'chaqueta',
    'chaqueton': 'chaqueta',
    'gorra': 'gorro',
    'sombrero': 'gorro',
    'boina': 'gorro',
    'lentes': 'gafas',
    'anteojos': 'gafas',
    'gafas_sol': 'gafas',
    'sombrilla': 'paraguas',
    'guante': 'guantes',
    'manoplas': 'guantes',
    'mitones': 'guantes',
    // Casa / muebles / objetos (variantes)
    'sillas': 'silla',
    'butaca': 'silla',
    'taburete': 'silla',
    'mesita': 'mesa',
    'escritorio': 'mesa',
    'litera': 'cama',
    'sillon': 'sofa',
    'lampara_mesa': 'lampara',
    'flexo': 'lampara',
    'porton': 'puerta',
    'ventanal': 'ventana',
    'movil': 'telefono',
    'telefono_movil': 'telefono',
    'celular': 'telefono',
    'smartphone': 'telefono',
    'tele': 'television',
    'televisor': 'television',
    'tv': 'television',
    'llaves': 'llave',
    'libros': 'libro',
    'cuaderno': 'libro',
    'lapicero': 'lapiz',
    'boligrafo': 'lapiz',
    'lapiz_color': 'lapiz',
    'tijera': 'tijeras',
    'peineta': 'peine',
    'cepillo_pelo': 'peine',
    'cepillo': 'cepillo_dientes',
    'cepillo_de_dientes': 'cepillo_dientes',
    'pastilla_jabon': 'jabon',
    'toallita': 'toalla',
    'espejito': 'espejo',
    // Herramientas (variantes)
    'martillos': 'martillo',
    'maza': 'martillo',
    'atornillador': 'destornillador',
    'llave_fija': 'llave_inglesa',
    'llave_tuercas': 'llave_inglesa',
    'llave_tubo': 'llave_inglesa',
    'serrucho': 'sierra',
    'brocha': 'pincel',
    'pinceles': 'pincel',
    // Vehículos (variantes)
    'automovil': 'coche',
    'auto': 'coche',
    'carro': 'coche',
    'coche_rojo': 'coche',
    'bus': 'autobus',
    'guagua': 'autobus',
    'bici': 'bicicleta',
    'ferrocarril': 'tren',
    'locomotora': 'tren',
    'aeroplano': 'avion',
    'avioneta': 'avion',
    'aeronave': 'avion',
    'bote': 'barco',
    'barca': 'barco',
    'velero': 'barco',
    'motocicleta': 'moto',
    'motociclo': 'moto',
    'camioneta': 'camion',
    'furgoneta': 'camion',
    'trailer': 'camion',
    // Naturaleza (variantes)
    'nubes': 'nube',
    'nubecita': 'nube',
    'arboles': 'arbol',
    'arbolito': 'arbol',
    'pino': 'arbol',
    'montanas': 'montana',
    'monte': 'montana',
    'colina': 'montana',
    'hojas': 'hoja',
    'hoja_verde': 'hoja',
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

  /// Fotos reales por id (sustituyen al dibujo). Se van añadiendo aquí a medida
  /// que haya fotos en `assets/fotos/` — estrategia de sustituir dibujos por
  /// fotos poco a poco. Vacío = por ahora solo dibujos. Ejemplo:
  ///   'perro': 'assets/fotos/perro.png',
  static const Map<String, String> _fotos = {};

  /// Ruta de la FOTO real para un id, o `null` si aún no hay foto (usar dibujo).
  static String? fotoPara(String raw) {
    final s = normaliza(raw);
    final canon = _alias[s] ?? s;
    return _fotos[canon] ?? _fotos[s];
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
