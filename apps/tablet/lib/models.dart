/// Modelos de datos que consume la app (espejo del contrato de la API).

class UsuarioFinal {
  final String id;
  final String aliasInterno;

  UsuarioFinal({required this.id, required this.aliasInterno});

  factory UsuarioFinal.fromJson(Map<String, dynamic> j) => UsuarioFinal(
        id: j['id'] as String,
        aliasInterno: j['alias_interno'] as String,
      );
}

class Ejercicio {
  final String id;
  final String bloque;
  final String plantillaTipo;
  final String nombre;

  Ejercicio({
    required this.id,
    required this.bloque,
    required this.plantillaTipo,
    required this.nombre,
  });

  factory Ejercicio.fromJson(Map<String, dynamic> j) => Ejercicio(
        id: j['id'] as String,
        bloque: j['bloque'] as String,
        plantillaTipo: j['plantilla_tipo'] as String,
        nombre: j['nombre'] as String,
      );
}

/// Una tirada concreta del ejercicio, generada por el motor de plantillas.
class Instancia {
  final String ejercicioId;
  final String nombre;
  final String bloque;
  final String plantilla;
  final Map<String, dynamic> render;
  final Map<String, dynamic> cantidadObjetivo;
  final List<String> metricas;

  Instancia({
    required this.ejercicioId,
    required this.nombre,
    required this.bloque,
    required this.plantilla,
    required this.render,
    required this.cantidadObjetivo,
    required this.metricas,
  });

  factory Instancia.fromJson(Map<String, dynamic> j) => Instancia(
        ejercicioId: j['ejercicio_id'] as String,
        nombre: j['nombre'] as String,
        bloque: j['bloque'] as String,
        plantilla: j['plantilla'] as String,
        render: Map<String, dynamic>.from(j['render'] as Map),
        cantidadObjetivo:
            Map<String, dynamic>.from(j['cantidad_objetivo'] as Map),
        metricas:
            (j['metricas'] as List).map((e) => e.toString()).toList(),
      );
}

/// Un intento a registrar. El `id` se genera en cliente (sync idempotente).
class Intento {
  final String id;
  final String usuarioFinalId;
  final String sesionId;
  final String ejercicioId;
  final String estado; // solo | con_ayuda | no_completado
  final DateTime timestampInicio;
  final DateTime? timestampFin;
  final Map<String, dynamic> valores;
  final Map<String, dynamic> cantidadObjetivo;

  Intento({
    required this.id,
    required this.usuarioFinalId,
    required this.sesionId,
    required this.ejercicioId,
    required this.estado,
    required this.timestampInicio,
    this.timestampFin,
    required this.valores,
    required this.cantidadObjetivo,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'usuario_final_id': usuarioFinalId,
        'sesion_id': sesionId,
        'ejercicio_id': ejercicioId,
        'estado': estado,
        'timestamp_inicio': timestampInicio.toUtc().toIso8601String(),
        if (timestampFin != null)
          'timestamp_fin': timestampFin!.toUtc().toIso8601String(),
        'valores_json': valores,
        'cantidad_objetivo_json': cantidadObjetivo,
      };
}
