"""Modelo de datos de Trazo.

Diseño con RGPD en mente (datos de salud = categoría especial):

- `usuarios_finales` (las personas mayores) se guardan PSEUDONIMIZADOS: solo un
  alias interno, nunca el nombre real, en las tablas de trabajo.
- El nombre real y datos identificativos viven en `datos_identificativos`, una
  tabla separada pensada para acceso restringido.
- `registro_auditoria` deja rastro de quién accede a datos de qué usuario final.

Tipos JSON/UUID: se usan tipos GENÉRICOS de SQLAlchemy (JSON, String para UUID)
para que el mismo modelo funcione en PostgreSQL (producción) y en SQLite (tests),
y para que la app de tablet pueda generar UUIDs en cliente (sync offline).
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy import JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


def _uuid() -> str:
    return str(uuid.uuid4())


def _now() -> datetime:
    return datetime.now(timezone.utc)


# --------------------------------------------------------------------------
#  Valores permitidos (documentados como constantes, no como ENUM de BD,
#  para mantener portabilidad y poder añadir valores sin migración de tipo).
# --------------------------------------------------------------------------

ROLES_STAFF = ("integradora", "admin_centro", "familia")

BLOQUES = (
    "atencion_memoria",
    "lenguaje",
    "razonamiento",
    "gnosias",
    "praxias",
    "percepcion",
    "funcion_ejecutiva",
    "vida_cotidiana",
)

PLANTILLAS = (
    "trazo",
    "seleccion_multiple",
    "memoria_visual",
    "secuencia_ordenar",
    "conteo_comparacion",
    "arrastrar_posicion",
    "evocacion_libre",
    "manejo_cantidad",
)

TIPOS_SESION = ("individual", "grupo")

MODOS_SESION = ("individual", "grupo")

ESTADOS_INTENTO = ("solo", "con_ayuda", "no_completado")

TIPOS_ALERTA = ("individual", "grupo")

# Líneas del plan de trabajo: por dominio (bloque) o por ejercicio concreto.
TIPOS_LINEA_PLAN = ("dominio", "ejercicio")

# Rol con el que se empareja una tablet al centro (ver MODELO-OPERATIVO §1).
ROLES_DISPOSITIVO = ("maestra", "participante")


# --------------------------------------------------------------------------
#  Entidades
# --------------------------------------------------------------------------


class Centro(Base):
    __tablename__ = "centros"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    nombre: Mapped[str] = mapped_column(String(200), nullable=False)
    activo: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    creado_en: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    staff: Mapped[list[UsuarioStaff]] = relationship(back_populates="centro")
    usuarios_finales: Mapped[list[UsuarioFinal]] = relationship(back_populates="centro")


class UsuarioStaff(Base):
    """Integradoras / admin del centro / familia (opcional)."""

    __tablename__ = "usuarios_staff"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    centro_id: Mapped[str] = mapped_column(ForeignKey("centros.id"), nullable=False)
    nombre: Mapped[str] = mapped_column(String(200), nullable=False)
    rol: Mapped[str] = mapped_column(String(30), nullable=False)  # ver ROLES_STAFF
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    activo: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    creado_en: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    centro: Mapped[Centro] = relationship(back_populates="staff")


class UsuarioFinal(Base):
    """Persona mayor — PSEUDONIMIZADA. Sin nombre real aquí."""

    __tablename__ = "usuarios_finales"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    centro_id: Mapped[str] = mapped_column(ForeignKey("centros.id"), nullable=False)
    alias_interno: Mapped[str] = mapped_column(String(80), nullable=False)
    fecha_alta: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    # Nivel base por bloque/ejercicio (dificultad de arranque personal).
    nivel_base_json: Mapped[dict] = mapped_column(JSON, default=dict)
    activo: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    centro: Mapped[Centro] = relationship(back_populates="usuarios_finales")
    datos_identificativos: Mapped[DatosIdentificativos | None] = relationship(
        back_populates="usuario_final", uselist=False
    )
    intentos: Mapped[list[Intento]] = relationship(back_populates="usuario_final")


class DatosIdentificativos(Base):
    """Nombre real y datos personales — tabla SEPARADA de acceso restringido.

    Se mantiene aparte de `usuarios_finales` a propósito: las consultas de
    trabajo (intentos, evolución, alertas) nunca necesitan tocar esta tabla.
    """

    __tablename__ = "datos_identificativos"

    usuario_final_id: Mapped[str] = mapped_column(
        ForeignKey("usuarios_finales.id"), primary_key=True
    )
    nombre_real: Mapped[str] = mapped_column(String(200), nullable=False)
    fecha_nacimiento: Mapped[datetime | None] = mapped_column(Date, nullable=True)
    notas: Mapped[str | None] = mapped_column(Text, nullable=True)

    usuario_final: Mapped[UsuarioFinal] = relationship(
        back_populates="datos_identificativos"
    )


class Consentimiento(Base):
    __tablename__ = "consentimientos"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    usuario_final_id: Mapped[str] = mapped_column(
        ForeignKey("usuarios_finales.id"), nullable=False
    )
    tipo: Mapped[str] = mapped_column(String(60), nullable=False)
    fecha: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    otorgado_por: Mapped[str] = mapped_column(String(200), nullable=False)
    documento_ref: Mapped[str | None] = mapped_column(String(255), nullable=True)


class Sesion(Base):
    __tablename__ = "sesiones"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    centro_id: Mapped[str] = mapped_column(ForeignKey("centros.id"), nullable=False)
    fecha: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    tipo: Mapped[str] = mapped_column(String(20), nullable=False)  # individual/grupo
    # `modo` refleja la forma de sesión del modelo operativo (§3). Se mantiene
    # `tipo` por compatibilidad; en la práctica ambos toman el mismo valor.
    modo: Mapped[str] = mapped_column(String(20), default="individual", nullable=False)
    # En modo grupo: el ejercicio compartido por todos (cada uno a su nivel).
    ejercicio_compartido_id: Mapped[str | None] = mapped_column(
        ForeignKey("ejercicios_catalogo.id"), nullable=True
    )
    # Nombre/etiqueta de la sala (ej. "Grupo tarde"). Solo etiqueta, no dato personal.
    nombre: Mapped[str | None] = mapped_column(String(120), nullable=True)
    staff_id: Mapped[str] = mapped_column(ForeignKey("usuarios_staff.id"), nullable=False)
    cerrada: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    # iniciada=False: montando/repartiendo. True: la maestra pulsó "Iniciar actividad".
    iniciada: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    # abierta=True: sala "en vivo" que ven los kioscos. abierta=False: sesión
    # PROGRAMADA/borrador (dejada lista para otro día); no aparece en /activa hasta
    # que la maestra la "abre". Las salas creadas al momento nacen abiertas.
    abierta: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    # Día para el que se dejó preparada (informativo; ordena la lista de programadas).
    programada_para: Mapped[datetime | None] = mapped_column(Date, nullable=True)

    participantes: Mapped[list[SesionParticipante]] = relationship(
        back_populates="sesion", cascade="all, delete-orphan"
    )
    intentos: Mapped[list[Intento]] = relationship(back_populates="sesion")


class SesionParticipante(Base):
    __tablename__ = "sesion_participantes"
    __table_args__ = (
        UniqueConstraint("sesion_id", "usuario_final_id", name="uq_sesion_usuario"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    sesion_id: Mapped[str] = mapped_column(ForeignKey("sesiones.id"), nullable=False)
    usuario_final_id: Mapped[str] = mapped_column(
        ForeignKey("usuarios_finales.id"), nullable=False
    )
    # Config de ESTA sesión que fija la maestra por participante (nivel + líneas
    # {bloque, n}). Si es None, se usa el plan permanente del paciente.
    # Formato: {"nivel": "medio", "lineas": [{"bloque": "razonamiento", "n": 4}, ...]}
    config_json: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    # Ronda actual (la maestra puede mandar "más" al terminar) y si terminó la ronda.
    ronda: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    terminado: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    sesion: Mapped[Sesion] = relationship(back_populates="participantes")


class EjercicioCatalogo(Base):
    """Un ejercicio = una fila de configuración sobre una PLANTILLA.

    Esta es la pieza clave del diseño data-driven: añadir un ejercicio nuevo es
    insertar una fila aquí, no escribir una pantalla de código.
    """

    __tablename__ = "ejercicios_catalogo"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    bloque: Mapped[str] = mapped_column(String(30), nullable=False)  # ver BLOQUES
    plantilla_tipo: Mapped[str] = mapped_column(String(30), nullable=False)  # PLANTILLAS
    nombre: Mapped[str] = mapped_column(String(200), nullable=False)
    descripcion: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Parámetros que consume la plantilla (imágenes, rangos de dificultad, etc.).
    parametros_json: Mapped[dict] = mapped_column(JSON, default=dict)
    activo: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    creado_en: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class Intento(Base):
    """Un intento de un ejercicio por una persona.

    El id puede venir generado por el cliente (tablet) para sync offline
    idempotente: reenviar el mismo UUID no duplica.
    """

    __tablename__ = "intentos"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    usuario_final_id: Mapped[str] = mapped_column(
        ForeignKey("usuarios_finales.id"), nullable=False
    )
    sesion_id: Mapped[str] = mapped_column(ForeignKey("sesiones.id"), nullable=False)
    ejercicio_id: Mapped[str] = mapped_column(
        ForeignKey("ejercicios_catalogo.id"), nullable=False
    )
    timestamp_inicio: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_now
    )
    timestamp_fin: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    # solo / con_ayuda / no_completado  -> NUNCA solo acierto/fallo
    estado: Mapped[str] = mapped_column(String(20), nullable=False)
    # Métricas específicas del tipo de ejercicio (precisión, tiempo, desviación...).
    valores_json: Mapped[dict] = mapped_column(JSON, default=dict)
    # Qué cantidades concretas se usaron esta vez (dificultad cambiante).
    # Imprescindible para que la comparación histórica de alertas sea justa.
    cantidad_objetivo_json: Mapped[dict] = mapped_column(JSON, default=dict)

    usuario_final: Mapped[UsuarioFinal] = relationship(back_populates="intentos")
    sesion: Mapped[Sesion] = relationship(back_populates="intentos")


class Alerta(Base):
    __tablename__ = "alertas"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    usuario_final_id: Mapped[str] = mapped_column(
        ForeignKey("usuarios_finales.id"), nullable=False
    )
    fecha_generada: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_now
    )
    tipo: Mapped[str] = mapped_column(String(20), nullable=False)  # individual/grupo
    bloque_afectado: Mapped[str | None] = mapped_column(String(30), nullable=True)
    descripcion: Mapped[str] = mapped_column(Text, nullable=False)
    # Contexto numérico de por qué saltó (media, desviación, valor observado...).
    contexto_json: Mapped[dict] = mapped_column(JSON, default=dict)
    revisada_por: Mapped[str | None] = mapped_column(
        ForeignKey("usuarios_staff.id"), nullable=True
    )
    fecha_revision: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    resultado: Mapped[str | None] = mapped_column(Text, nullable=True)


class PlanPacienteLinea(Base):
    """Una línea del plan de trabajo de una persona (ver MODELO-OPERATIVO §2).

    Diseño "mixto": una persona puede tener líneas por DOMINIO (el motor rota
    ejercicios de ese bloque) y/o líneas de EJERCICIO concreto (uno fijado a
    propósito). El nº por sesión y el orden definen cómo se construye su cola.
    """

    __tablename__ = "planes_paciente"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    usuario_final_id: Mapped[str] = mapped_column(
        ForeignKey("usuarios_finales.id"), nullable=False
    )
    tipo: Mapped[str] = mapped_column(String(20), nullable=False)  # ver TIPOS_LINEA_PLAN
    # Si tipo == 'dominio': el bloque del que rotar ejercicios.
    bloque: Mapped[str | None] = mapped_column(String(30), nullable=True)
    # Si tipo == 'ejercicio': el ejercicio concreto fijado.
    ejercicio_id: Mapped[str | None] = mapped_column(
        ForeignKey("ejercicios_catalogo.id"), nullable=True
    )
    # Nivel sugerido/aprobado por el profesional (bajo/medio/alto o entero como str).
    nivel: Mapped[str | None] = mapped_column(String(20), nullable=True)
    n_por_sesion: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    orden: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    activo: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)


class Dispositivo(Base):
    """Tablet emparejada al centro (ver MODELO-OPERATIVO §1).

    Se empareja una sola vez; a partir de ahí es "del centro" y no pide login.
    Revocable (activo=False) desde la web si se pierde una — importante RGPD.
    """

    __tablename__ = "dispositivos"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    centro_id: Mapped[str] = mapped_column(ForeignKey("centros.id"), nullable=False)
    nombre: Mapped[str] = mapped_column(String(200), nullable=False)
    rol: Mapped[str] = mapped_column(String(20), nullable=False)  # ver ROLES_DISPOSITIVO
    # Token de emparejamiento (único). La tablet lo guarda y lo presenta.
    token: Mapped[str] = mapped_column(String(64), unique=True, nullable=False, default=_uuid)
    activo: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    emparejado_en: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class RegistroAuditoria(Base):
    """Rastro de acceso a datos de usuarios finales (exigible por RGPD)."""

    __tablename__ = "registro_auditoria"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    staff_id: Mapped[str] = mapped_column(ForeignKey("usuarios_staff.id"), nullable=False)
    usuario_final_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    accion: Mapped[str] = mapped_column(String(120), nullable=False)
    detalle: Mapped[str | None] = mapped_column(Text, nullable=True)
    fecha: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
