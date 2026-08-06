// Modelos de datos que consume la app (espejo del contrato de la API).

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

/// Un participante dentro de una sesión (lo que devuelve /sesiones/activa).
class ParticipanteSesion {
  final String usuarioFinalId;
  final String aliasInterno;

  ParticipanteSesion({required this.usuarioFinalId, required this.aliasInterno});

  factory ParticipanteSesion.fromJson(Map<String, dynamic> j) =>
      ParticipanteSesion(
        usuarioFinalId: j['usuario_final_id'] as String,
        aliasInterno: (j['alias_interno'] ?? '') as String,
      );
}

/// Estado de una sesión activa en el centro (kiosco del participante).
class SesionActiva {
  final String? sesionId;
  final String nombre;
  final bool iniciada;
  final String modo;
  final List<ParticipanteSesion> participantes;

  SesionActiva({
    required this.sesionId,
    required this.nombre,
    required this.iniciada,
    required this.modo,
    required this.participantes,
  });

  bool get haySesion => sesionId != null;

  factory SesionActiva.fromJson(Map<String, dynamic> j) => SesionActiva(
        sesionId: j['sesion_id'] as String?,
        nombre: (j['nombre'] ?? '') as String,
        iniciada: (j['iniciada'] ?? false) as bool,
        modo: (j['modo'] ?? 'individual') as String,
        participantes: ((j['participantes'] ?? []) as List)
            .map((e) =>
                ParticipanteSesion.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Ficha de un participante en el monitor en vivo de la maestra.
class FichaLive {
  final String usuarioFinalId;
  final String aliasInterno;
  final String? ejercicioActual;
  final String? ultimoEstado;
  final String? ultimoIntentoId;
  final int? segundosDesdeUltimoIntento;
  final bool atascado;

  FichaLive({
    required this.usuarioFinalId,
    required this.aliasInterno,
    required this.ejercicioActual,
    required this.ultimoEstado,
    required this.ultimoIntentoId,
    required this.segundosDesdeUltimoIntento,
    required this.atascado,
  });

  factory FichaLive.fromJson(Map<String, dynamic> j) => FichaLive(
        usuarioFinalId: j['usuario_final_id'] as String,
        aliasInterno: (j['alias_interno'] ?? '') as String,
        ejercicioActual: j['ejercicio_actual'] as String?,
        ultimoEstado: j['ultimo_estado'] as String?,
        ultimoIntentoId: j['ultimo_intento_id'] as String?,
        segundosDesdeUltimoIntento:
            (j['segundos_desde_ultimo_intento'] as num?)?.toInt(),
        atascado: (j['atascado'] ?? false) as bool,
      );
}

/// Un elemento de la cola del participante (desde su plan / ejercicio compartido).
class ColaItem {
  final String ejercicioId;
  final String nombre;
  final String bloque;
  final String plantilla;
  final String? nivel; // "bajo" | "medio" | "alto" (banda de cantidad)
  final String? origen;

  ColaItem({
    required this.ejercicioId,
    required this.nombre,
    required this.bloque,
    required this.plantilla,
    required this.nivel,
    required this.origen,
  });

  factory ColaItem.fromJson(Map<String, dynamic> j) => ColaItem(
        ejercicioId: j['ejercicio_id'] as String,
        nombre: (j['nombre'] ?? '') as String,
        bloque: (j['bloque'] ?? '') as String,
        plantilla: (j['plantilla'] ?? '') as String,
        nivel: j['nivel']?.toString(),
        origen: j['origen'] as String?,
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
