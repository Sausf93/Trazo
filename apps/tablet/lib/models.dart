// Modelos de datos que consume la app (espejo del contrato de la API).

/// Los 8 bloques (categorías) con su etiqueta bonita para la UI.
const Map<String, String> kBloques = {
  'atencion_memoria': 'Atención y memoria',
  'lenguaje': 'Lenguaje',
  'razonamiento': 'Razonamiento',
  'gnosias': 'Gnosias',
  'praxias': 'Praxias',
  'percepcion': 'Percepción',
  'funcion_ejecutiva': 'Función ejecutiva',
  'vida_cotidiana': 'Vida cotidiana',
};

/// Etiqueta bonita de un bloque (o el propio id si no está en el mapa).
String etiquetaBloque(String bloque) => kBloques[bloque] ?? bloque;

/// Una línea del plan de trabajo de la persona (`GET /usuarios/{id}/plan`).
class PlanLinea {
  final String tipo; // "dominio" | "ejercicio"
  final String? bloque; // requerido si tipo=dominio
  final String? ejercicioId; // requerido si tipo=ejercicio
  final String? nivel; // bajo/medio/alto (o entero como str)
  final int nPorSesion;
  final int orden;
  final bool activo;

  PlanLinea({
    required this.tipo,
    required this.bloque,
    required this.ejercicioId,
    required this.nivel,
    required this.nPorSesion,
    required this.orden,
    required this.activo,
  });

  factory PlanLinea.fromJson(Map<String, dynamic> j) => PlanLinea(
        tipo: (j['tipo'] ?? 'dominio') as String,
        bloque: j['bloque'] as String?,
        ejercicioId: j['ejercicio_id'] as String?,
        nivel: j['nivel']?.toString(),
        nPorSesion: (j['n_por_sesion'] as num?)?.toInt() ?? 1,
        orden: (j['orden'] as num?)?.toInt() ?? 0,
        activo: (j['activo'] ?? true) as bool,
      );
}

/// Estado de un participante dentro de una sesión (`GET .../estado`).
class EstadoParticipante {
  final bool iniciada;
  final int ronda;
  final bool terminado;

  EstadoParticipante({
    required this.iniciada,
    required this.ronda,
    required this.terminado,
  });

  factory EstadoParticipante.fromJson(Map<String, dynamic> j) =>
      EstadoParticipante(
        iniciada: (j['iniciada'] ?? false) as bool,
        ronda: (j['ronda'] as num?)?.toInt() ?? 0,
        terminado: (j['terminado'] ?? false) as bool,
      );
}

/// Una línea de config de un participante en una sesión programada ({bloque, n}).
class LineaConfig {
  final String bloque;
  final int n;

  LineaConfig({required this.bloque, required this.n});

  factory LineaConfig.fromJson(Map<String, dynamic> j) => LineaConfig(
        bloque: (j['bloque'] ?? '') as String,
        n: (j['n'] as num?)?.toInt() ?? 1,
      );
}

/// Un participante de una sesión programada, con su config ya fijada.
class ParticipanteProgramado {
  final String usuarioFinalId;
  final String aliasInterno;
  final String? nivel;
  final List<LineaConfig> lineas;

  ParticipanteProgramado({
    required this.usuarioFinalId,
    required this.aliasInterno,
    required this.nivel,
    required this.lineas,
  });

  factory ParticipanteProgramado.fromJson(Map<String, dynamic> j) =>
      ParticipanteProgramado(
        usuarioFinalId: j['usuario_final_id'] as String,
        aliasInterno: (j['alias_interno'] ?? '') as String,
        nivel: j['nivel']?.toString(),
        lineas: ((j['lineas'] ?? []) as List)
            .map((e) => LineaConfig.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Nº total de actividades configuradas (suma de las líneas).
  int get totalActividades => lineas.fold(0, (a, l) => a + l.n);
}

/// Una sala dejada PREPARADA (programada) para otro día (`GET /sesiones/programadas`).
class SesionProgramada {
  final String id;
  final String nombre;
  final String modo;
  final String? programadaPara; // 'YYYY-MM-DD'
  final List<ParticipanteProgramado> participantes;

  SesionProgramada({
    required this.id,
    required this.nombre,
    required this.modo,
    required this.programadaPara,
    required this.participantes,
  });

  factory SesionProgramada.fromJson(Map<String, dynamic> j) => SesionProgramada(
        id: j['id'] as String,
        nombre: (j['nombre'] ?? 'Sesión') as String,
        modo: (j['modo'] ?? 'individual') as String,
        programadaPara: j['programada_para']?.toString(),
        participantes: ((j['participantes'] ?? []) as List)
            .map((e) =>
                ParticipanteProgramado.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

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
  final bool terminado;
  final int ronda;

  FichaLive({
    required this.usuarioFinalId,
    required this.aliasInterno,
    required this.ejercicioActual,
    required this.ultimoEstado,
    required this.ultimoIntentoId,
    required this.segundosDesdeUltimoIntento,
    required this.atascado,
    required this.terminado,
    required this.ronda,
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
        terminado: (j['terminado'] ?? false) as bool,
        ronda: (j['ronda'] as num?)?.toInt() ?? 0,
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
