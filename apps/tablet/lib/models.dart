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

/// Contexto de una tablet emparejada (`GET /dispositivos/yo`).
class DispositivoYo {
  final String id;
  final String centroId;
  final String nombre;
  final String rol;

  DispositivoYo({
    required this.id,
    required this.centroId,
    required this.nombre,
    required this.rol,
  });

  factory DispositivoYo.fromJson(Map<String, dynamic> j) => DispositivoYo(
        id: j['id'] as String,
        centroId: j['centro_id'] as String,
        nombre: (j['nombre'] ?? '') as String,
        rol: (j['rol'] ?? 'participante') as String,
      );
}

/// Una sesión del historial del centro (`GET /sesiones?estado=`).
class SesionHistorial {
  final String id;
  final String nombre;
  final String fecha; // ISO
  final int nParticipantes;
  final bool cerrada;
  final String? staffNombre; // quién la abrió (para avisar de sala duplicada)

  SesionHistorial({
    required this.id,
    required this.nombre,
    required this.fecha,
    required this.nParticipantes,
    required this.cerrada,
    this.staffNombre,
  });

  factory SesionHistorial.fromJson(Map<String, dynamic> j) => SesionHistorial(
        id: j['id'] as String,
        nombre: (j['nombre'] ?? 'Sesión') as String,
        fecha: (j['fecha'] ?? '') as String,
        nParticipantes: (j['n_participantes'] as num?)?.toInt() ?? 0,
        cerrada: (j['cerrada'] ?? false) as bool,
        staffNombre: j['staff_nombre'] as String?,
      );

  /// Fecha en formato corto "dd/mm hh:mm" para la UI.
  String get fechaCorta {
    final d = DateTime.tryParse(fecha)?.toLocal();
    if (d == null) return '';
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(d.day)}/${dos(d.month)} ${dos(d.hour)}:${dos(d.minute)}';
  }
}

/// Resumen de un participante al finalizar la sesión (`GET .../resumen`).
class FichaResumen {
  final String aliasInterno;
  final int nIntentos;
  final int logrado;
  final int parcial;
  final int noLogrado;
  final int sinValorar;
  final int conAyuda;

  FichaResumen({
    required this.aliasInterno,
    required this.nIntentos,
    required this.logrado,
    required this.parcial,
    required this.noLogrado,
    this.sinValorar = 0,
    this.conAyuda = 0,
  });

  factory FichaResumen.fromJson(Map<String, dynamic> j) => FichaResumen(
        aliasInterno: (j['alias_interno'] ?? '') as String,
        nIntentos: (j['n_intentos'] as num?)?.toInt() ?? 0,
        logrado: (j['logrado'] as num?)?.toInt() ?? 0,
        parcial: (j['parcial'] as num?)?.toInt() ?? 0,
        noLogrado: (j['no_logrado'] as num?)?.toInt() ?? 0,
        sinValorar: (j['sin_valorar'] as num?)?.toInt() ?? 0,
        conAyuda: (j['con_ayuda'] as num?)?.toInt() ?? 0,
      );
}

class ResumenSesion {
  final String sesionId;
  final String nombre;
  final String? notas;
  final List<FichaResumen> fichas;

  ResumenSesion(
      {required this.sesionId,
      required this.nombre,
      this.notas,
      required this.fichas});

  factory ResumenSesion.fromJson(Map<String, dynamic> j) => ResumenSesion(
        sesionId: (j['sesion_id'] ?? '') as String,
        nombre: (j['nombre'] ?? 'Sesión') as String,
        notas: j['notas'] as String?,
        fichas: ((j['fichas'] ?? []) as List)
            .map((e) => FichaResumen.fromJson(e as Map<String, dynamic>))
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
/// Un intento reciente para revisar/marcar en lote desde el monitor.
class IntentoRevision {
  final String id;
  final String ejercicio;
  final String resultado;
  final bool conAyuda;

  IntentoRevision(
      {required this.id,
      required this.ejercicio,
      required this.resultado,
      required this.conAyuda});

  factory IntentoRevision.fromJson(Map<String, dynamic> j) => IntentoRevision(
        id: j['id'] as String,
        ejercicio: (j['ejercicio'] ?? '') as String,
        resultado: (j['resultado'] ?? 'sin_valorar') as String,
        conAyuda: (j['con_ayuda'] ?? false) as bool,
      );
}

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
/// Un profesional del centro, para el selector "¿quién eres?" de la maestra.
class StaffPick {
  final String id;
  final String nombre;
  final String rol;
  final bool tienePin;

  StaffPick({required this.id, required this.nombre, required this.rol, required this.tienePin});

  factory StaffPick.fromJson(Map<String, dynamic> j) => StaffPick(
        id: j['id'] as String,
        nombre: (j['nombre'] ?? '') as String,
        rol: (j['rol'] ?? '') as String,
        tienePin: (j['tiene_pin'] ?? false) as bool,
      );
}

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

/// Una sala (sesión) abierta del centro, con quién juega en ella.
class SalaActiva {
  final String sesionId;
  final String nombre;
  final bool iniciada;
  final String modo;
  final String? responsable; // maestra que abrió la sala (para distinguirlas)
  final List<ParticipanteSesion> participantes;

  SalaActiva({
    required this.sesionId,
    required this.nombre,
    required this.iniciada,
    required this.modo,
    required this.participantes,
    this.responsable,
  });

  factory SalaActiva.fromJson(Map<String, dynamic> j) => SalaActiva(
        sesionId: j['sesion_id'] as String,
        nombre: (j['nombre'] ?? '') as String,
        iniciada: (j['iniciada'] ?? false) as bool,
        modo: (j['modo'] ?? 'individual') as String,
        responsable: j['responsable'] as String?,
        participantes: ((j['participantes'] ?? []) as List)
            .map((e) =>
                ParticipanteSesion.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Estado de las salas abiertas del centro (kiosco del participante).
///
/// Un centro puede tener VARIAS salas a la vez (2 maestras, 2 grupos). El
/// kiosco muestra las salas para que cada persona elija a cuál unirse. Los
/// campos "planos" (sesionId/participantes…) reflejan la 1ª sala por compat.
class SesionActiva {
  final String? sesionId;
  final String nombre;
  final bool iniciada;
  final String modo;
  final List<ParticipanteSesion> participantes;
  final List<SalaActiva> salas;

  SesionActiva({
    required this.sesionId,
    required this.nombre,
    required this.iniciada,
    required this.modo,
    required this.participantes,
    this.salas = const [],
  });

  bool get haySesion => salas.isNotEmpty || sesionId != null;
  bool get variasSalas => salas.length > 1;

  /// La sala con ese id entre las abiertas, o null si ya se cerró.
  SalaActiva? salaConId(String sesionId) {
    for (final s in salas) {
      if (s.sesionId == sesionId) return s;
    }
    return null;
  }

  /// Busca la sala a la que pertenece una persona (por si el kiosco ya la tiene
  /// elegida): devuelve null si ya no está en ninguna sala abierta.
  SalaActiva? salaDe(String usuarioFinalId) {
    for (final s in salas) {
      if (s.participantes.any((p) => p.usuarioFinalId == usuarioFinalId)) {
        return s;
      }
    }
    return null;
  }

  factory SesionActiva.fromJson(Map<String, dynamic> j) {
    final salas = ((j['salas'] ?? []) as List)
        .map((e) => SalaActiva.fromJson(e as Map<String, dynamic>))
        .toList();
    return SesionActiva(
      sesionId: j['sesion_id'] as String?,
      nombre: (j['nombre'] ?? '') as String,
      iniciada: (j['iniciada'] ?? false) as bool,
      modo: (j['modo'] ?? 'individual') as String,
      participantes: ((j['participantes'] ?? []) as List)
          .map((e) => ParticipanteSesion.fromJson(e as Map<String, dynamic>))
          .toList(),
      salas: salas,
    );
  }
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
  final int posActual;
  final int totalActual;
  final bool ultimoConAyuda; // si la integradora marcó ayuda en el último intento

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
    required this.posActual,
    required this.totalActual,
    this.ultimoConAyuda = false,
  });

  factory FichaLive.fromJson(Map<String, dynamic> j) => FichaLive(
        usuarioFinalId: j['usuario_final_id'] as String,
        aliasInterno: (j['alias_interno'] ?? '') as String,
        ejercicioActual: j['ejercicio_actual'] as String?,
        ultimoEstado: j['ultimo_estado'] as String?, // resultado autocorregido
        ultimoConAyuda: (j['ultimo_con_ayuda'] ?? false) as bool,
        ultimoIntentoId: j['ultimo_intento_id'] as String?,
        segundosDesdeUltimoIntento:
            (j['segundos_desde_ultimo_intento'] as num?)?.toInt(),
        atascado: (j['atascado'] ?? false) as bool,
        terminado: (j['terminado'] ?? false) as bool,
        ronda: (j['ronda'] as num?)?.toInt() ?? 0,
        posActual: (j['pos_actual'] as num?)?.toInt() ?? 0,
        totalActual: (j['total_actual'] as num?)?.toInt() ?? 0,
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
