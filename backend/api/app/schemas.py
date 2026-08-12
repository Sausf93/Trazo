"""Esquemas Pydantic (entrada/salida de la API)."""
from __future__ import annotations

from datetime import date, datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from app.models import BLOQUES

NIVELES = ("bajo", "medio", "alto")


# ---- Auth ----

class LoginIn(BaseModel):
    email: EmailStr
    password: str


# ---- Equipo (staff del centro) ----

# El email se trata como texto (igual que en el login): usar EmailStr rechazaría
# dominios reservados como `.local`, que usamos en pruebas.
def _email_basico(v: str) -> str:
    v = v.strip().lower()
    if "@" not in v or "." not in v.split("@")[-1] or len(v) < 5:
        raise ValueError("email no válido")
    return v


class StaffIn(BaseModel):
    nombre: str = Field(min_length=1, max_length=200)
    email: str
    password: str = Field(min_length=8, max_length=128)
    # El admin del centro da de alta integradoras; puede crear otro admin si quiere.
    rol: str = "integradora"

    _norm_email = field_validator("email")(_email_basico)

    @field_validator("rol")
    @classmethod
    def _rol_valido(cls, v: str) -> str:
        if v not in ("integradora", "admin_centro"):
            raise ValueError("rol debe ser 'integradora' o 'admin_centro'")
        return v


class StaffUpdate(BaseModel):
    nombre: str | None = Field(default=None, min_length=1, max_length=200)
    activo: bool | None = None


class StaffOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    centro_id: str
    nombre: str
    email: str
    rol: str
    activo: bool


# ---- Plataforma (nivel 0: alta de centros) ----

class CentroPlataformaIn(BaseModel):
    centro: str = Field(min_length=1, max_length=200)
    email: str
    password: str = Field(min_length=8, max_length=128)
    nombre: str = "Administración del centro"

    _norm_email = field_validator("email")(_email_basico)


class CentroPlataformaOut(BaseModel):
    mensaje: str
    creado: bool


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    id: str
    rol: str
    nombre: str
    centro_id: str


# ---- Usuarios finales ----

class UsuarioFinalIn(BaseModel):
    alias_interno: str
    # Datos identificativos opcionales -> van a la tabla separada restringida.
    nombre_real: str | None = None
    nivel_base_json: dict[str, Any] = Field(default_factory=dict)


class ConsentimientoIn(BaseModel):
    """Registro de un consentimiento otorgado para una persona usuaria."""
    tipo: str = "uso_y_seguimiento"  # p. ej. uso_y_seguimiento | imagen
    otorgado_por: str  # nombre de quien lo otorga (titular o representante)
    rol_otorgante: str = "titular"  # titular|representante_legal|tutor|guardador_hecho
    documento_ref: str | None = None  # referencia al documento firmado (archivador)


class ConsentimientoOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    usuario_final_id: str
    tipo: str
    fecha: datetime
    otorgado_por: str
    rol_otorgante: str
    documento_ref: str | None


class UsuarioFinalUpdate(BaseModel):
    """Editar un usuario final: alias y/o nivel base. Campos omitidos no cambian."""
    alias_interno: str | None = None
    nivel_base_json: dict[str, Any] | None = None


class UsuarioFinalOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    centro_id: str
    alias_interno: str
    fecha_alta: datetime
    nivel_base_json: dict[str, Any]
    activo: bool


# ---- Ejercicios ----

class EjercicioIn(BaseModel):
    bloque: str
    plantilla_tipo: str
    nombre: str
    descripcion: str | None = None
    parametros_json: dict[str, Any] = Field(default_factory=dict)
    activo: bool = True


class EjercicioOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    bloque: str
    plantilla_tipo: str
    nombre: str
    descripcion: str | None
    parametros_json: dict[str, Any]
    activo: bool


class InstanciaOut(BaseModel):
    """Una tirada concreta generada por el motor de plantillas."""
    ejercicio_id: str
    nombre: str
    bloque: str
    plantilla: str
    render: dict[str, Any]
    cantidad_objetivo: dict[str, Any]
    metricas: list[str]


# ---- Sesiones ----

def _validar_nivel(v: str | None) -> str | None:
    """Nivel de sesión: solo bajo/medio/alto (None = usa el del plan)."""
    if v is not None and v not in NIVELES:
        raise ValueError(f"nivel inválido: {v} (usa {', '.join(NIVELES)})")
    return v


class LineaConfig(BaseModel):
    """Una categoría (bloque) y cuántas actividades de ella en la sesión."""
    bloque: str
    n: int = Field(default=1, ge=1, le=50)

    @field_validator("bloque")
    @classmethod
    def _bloque_valido(cls, v: str) -> str:
        if v not in BLOQUES:
            raise ValueError(f"bloque inválido: {v}")
        return v


class ParticipanteConfigIn(BaseModel):
    """Config que fija la maestra para un participante en ESTA sesión.

    Si un participante trae config, su cola sale de aquí (nivel + líneas); si no,
    de su plan permanente.
    """
    usuario_final_id: str
    nivel: str | None = None  # bajo | medio | alto (aplica a toda su sesión)
    lineas: list[LineaConfig] = Field(default_factory=list)

    _nivel_ok = field_validator("nivel")(_validar_nivel)


class SesionIn(BaseModel):
    tipo: str = "individual"  # individual | grupo
    # Nombre/etiqueta de la sala (ej. "Grupo tarde"). Opcional; no es dato personal.
    nombre: str | None = None
    # `modo` es el término del modelo operativo (§3). Si se omite, se toma `tipo`.
    modo: str | None = None  # individual | grupo
    # En modo grupo: ejercicio compartido por todos (cada uno a su nivel).
    ejercicio_compartido_id: str | None = None
    participantes: list[str] = Field(default_factory=list)  # ids usuarios_finales
    # Config por participante para esta sesión (opcional). Los que no aparezcan
    # usan su plan permanente.
    configs: list[ParticipanteConfigIn] = Field(default_factory=list)
    # Si es True, la sesión se guarda PROGRAMADA (borrador para otro día): no se
    # abre para los kioscos hasta que la maestra la "abra". Por defecto se crea
    # abierta al momento (comportamiento clásico de "Abrir sala").
    programar: bool = False
    # Día para el que se deja preparada (informativo). Opcional.
    programada_para: date | None = None


class SesionConfigPut(BaseModel):
    """Reemplaza participantes/config/datos de una sesión PROGRAMADA (edición previa)."""
    nombre: str | None = None
    modo: str | None = None
    programada_para: date | None = None
    participantes: list[str] = Field(default_factory=list)
    configs: list[ParticipanteConfigIn] = Field(default_factory=list)


class ParticipanteMasIn(BaseModel):
    """Otra tanda para un participante que terminó (opcional, nueva config)."""
    nivel: str | None = None
    lineas: list[LineaConfig] = Field(default_factory=list)

    _nivel_ok = field_validator("nivel")(_validar_nivel)


class ActividadActualIn(BaseModel):
    """Qué actividad está haciendo AHORA la persona (lo reporta el kiosco)."""
    actividad: str | None = None
    pos: int = 0
    total: int = 0


class ParticipanteEstadoOut(BaseModel):
    """Estado que consulta la tablet del participante (polling)."""
    iniciada: bool
    ronda: int
    terminado: bool


class SesionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    centro_id: str
    fecha: datetime
    tipo: str
    modo: str
    nombre: str | None
    ejercicio_compartido_id: str | None
    staff_id: str
    cerrada: bool
    iniciada: bool
    abierta: bool = True
    programada_para: date | None = None


class ParticipanteProgramadoOut(BaseModel):
    """Un participante de una sesión programada, con su config ya fijada."""
    usuario_final_id: str
    alias_interno: str
    nivel: str | None = None
    lineas: list[LineaConfig] = Field(default_factory=list)


class SesionResumenOut(BaseModel):
    """Fila del listado de sesiones (historial / salas abiertas) del centro."""
    id: str
    nombre: str | None = None
    fecha: datetime
    modo: str
    abierta: bool
    iniciada: bool
    cerrada: bool
    n_participantes: int
    # Quién la abrió (para avisar si otra facilitadora ya tiene sala abierta).
    staff_id: str | None = None
    staff_nombre: str | None = None


class ResumenParticipante(BaseModel):
    usuario_final_id: str
    alias_interno: str
    n_intentos: int  # actividades con resultado (logrado+parcial+no_logrado)
    logrado: int
    parcial: int
    no_logrado: int
    sin_valorar: int = 0  # no-intento o pendientes de revisión (no cuentan)
    con_ayuda: int = 0    # de las hechas, en cuántas ayudó la integradora (matiz)


class ResumenSesionOut(BaseModel):
    """Cómo fue la sesión: por participante, desglose de estados."""
    sesion_id: str
    nombre: str | None = None
    notas: str | None = None
    fichas: list[ResumenParticipante] = Field(default_factory=list)


class NotaSesionIn(BaseModel):
    """Observaciones libres de la facilitadora sobre la sesión."""
    nota: str = Field(default="", max_length=2000)


class SesionProgramadaOut(BaseModel):
    """Sesión programada (borrador) con sus participantes y config, para que la
    maestra la revise y la abra el día señalado."""
    id: str
    nombre: str | None = None
    modo: str
    programada_para: date | None = None
    fecha: datetime
    participantes: list[ParticipanteProgramadoOut] = Field(default_factory=list)


# ---- Plan de trabajo por paciente ----

class PlanLineaIn(BaseModel):
    tipo: str  # dominio | ejercicio
    bloque: str | None = None  # requerido si tipo == dominio
    ejercicio_id: str | None = None  # requerido si tipo == ejercicio
    nivel: str | None = None  # bajo/medio/alto o entero como str
    n_por_sesion: int = Field(default=1, ge=1, le=50)
    orden: int = 0
    activo: bool = True


class PlanLineaOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    usuario_final_id: str
    tipo: str
    bloque: str | None
    ejercicio_id: str | None
    nivel: str | None
    n_por_sesion: int
    orden: int
    activo: bool


class PlanPut(BaseModel):
    """Reemplaza por completo las líneas del plan de la persona."""
    lineas: list[PlanLineaIn] = Field(default_factory=list)


# ---- Cola de ejercicios (resuelta desde el plan) ----

class ItemCola(BaseModel):
    ejercicio_id: str
    nombre: str
    bloque: str
    plantilla: str
    nivel: str | None = None
    origen: str  # 'dominio' | 'ejercicio' | 'grupo'
    plan_linea_id: str | None = None


class ColaOut(BaseModel):
    usuario_final_id: str
    sesion_id: str | None = None
    modo: str  # individual | grupo
    items: list[ItemCola]


# ---- Dispositivos (tablets emparejadas) ----

class DispositivoIn(BaseModel):
    nombre: str
    rol: str  # maestra | participante
    centro_id: str | None = None  # por defecto, el centro del staff


class DispositivoOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    centro_id: str
    nombre: str
    rol: str
    token: str
    activo: bool
    emparejado_en: datetime


class DispositivoYoOut(BaseModel):
    """Contexto que recibe la tablet al validar su token (sin exponer el token)."""
    id: str
    centro_id: str
    nombre: str
    rol: str


# ---- Auto-sugerencia de nivel ----

class SugerenciaNivelOut(BaseModel):
    plan_linea_id: str
    bloque: str
    nivel_actual: str | None
    sugerencia: str  # subir | bajar
    nivel_propuesto: str
    motivo: str
    media_reciente: float
    n_intentos: int


class NivelLineaIn(BaseModel):
    nivel: str  # bajo | medio | alto


# ---- Sesión activa (para la tablet participante / kiosco) ----

class ParticipanteSesion(BaseModel):
    usuario_final_id: str
    alias_interno: str


class SesionActivaOut(BaseModel):
    sesion_id: str | None = None
    nombre: str | None = None
    modo: str | None = None
    iniciada: bool = False
    ejercicio_compartido_id: str | None = None
    participantes: list[ParticipanteSesion] = Field(default_factory=list)


# ---- Intentos ----

class IntentoIn(BaseModel):
    # id opcional: la tablet puede generarlo (UUID) para sync offline idempotente.
    id: str | None = None
    usuario_final_id: str
    sesion_id: str
    ejercicio_id: str
    estado: str  # solo | con_ayuda | no_completado
    timestamp_inicio: datetime | None = None
    timestamp_fin: datetime | None = None
    valores_json: dict[str, Any] = Field(default_factory=dict)
    cantidad_objetivo_json: dict[str, Any] = Field(default_factory=dict)


class IntentoOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    usuario_final_id: str
    sesion_id: str
    ejercicio_id: str
    estado: str
    resultado: str = "sin_valorar"  # autocorregido (señal primaria)
    con_ayuda: bool = False          # marcado por la integradora (secundario)
    timestamp_inicio: datetime
    timestamp_fin: datetime | None
    valores_json: dict[str, Any]
    cantidad_objetivo_json: dict[str, Any]


class EstadoIntentoIn(BaseModel):
    estado: str  # solo | con_ayuda | no_completado (histórico)


class AyudaIntentoIn(BaseModel):
    """La integradora marca/desmarca que AYUDÓ en esta actividad concreta."""
    con_ayuda: bool = True


class ResultadoIntentoIn(BaseModel):
    """La integradora fija el resultado de una actividad que la app no supo
    juzgar (cola de revisión): logrado | parcial | no_logrado."""
    resultado: str


# ---- Evolución ----

class PuntoEvolucion(BaseModel):
    fecha: datetime
    ejercicio_id: str
    bloque: str
    estado: str
    precision: float | None = None
    valores: dict[str, Any] = Field(default_factory=dict)


class EvolucionOut(BaseModel):
    usuario_final_id: str
    bloque: str | None
    puntos: list[PuntoEvolucion]
    resumen: dict[str, Any] = Field(default_factory=dict)


# ---- Alertas ----

class AlertaOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    usuario_final_id: str
    fecha_generada: datetime
    tipo: str
    bloque_afectado: str | None
    descripcion: str
    contexto_json: dict[str, Any]
    revisada_por: str | None
    fecha_revision: datetime | None
    resultado: str | None


class RevisarAlertaIn(BaseModel):
    resultado: str


# ---- Vista en vivo (facilitadora) ----

class FichaViva(BaseModel):
    usuario_final_id: str
    alias_interno: str
    ejercicio_actual: str | None = None
    ultimo_estado: str | None = None  # resultado autocorregido del último intento
    ultimo_con_ayuda: bool = False    # si la integradora marcó ayuda en él
    ultimo_intento_id: str | None = None  # para marcar "le ayudé" desde la maestra
    segundos_desde_ultimo_intento: float | None = None
    atascado: bool = False
    terminado: bool = False  # terminó su tanda; la maestra puede "enviar más"
    ronda: int = 1
    # Actividad EN CURSO (reportada por el kiosco), para el monitor en vivo.
    actividad_actual: str | None = None
    pos_actual: int = 0
    total_actual: int = 0


class LiveOut(BaseModel):
    sesion_id: str
    tipo: str
    fichas: list[FichaViva]


class IntentoRevisionOut(BaseModel):
    """Un intento reciente de una persona, para revisar/marcar en lote."""
    id: str
    ejercicio: str
    resultado: str
    con_ayuda: bool
    cuando: datetime
