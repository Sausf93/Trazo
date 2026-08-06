"""Esquemas Pydantic (entrada/salida de la API)."""
from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, EmailStr, Field


# ---- Auth ----

class LoginIn(BaseModel):
    email: EmailStr
    password: str


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    rol: str
    nombre: str
    centro_id: str


# ---- Usuarios finales ----

class UsuarioFinalIn(BaseModel):
    alias_interno: str
    # Datos identificativos opcionales -> van a la tabla separada restringida.
    nombre_real: str | None = None
    nivel_base_json: dict[str, Any] = Field(default_factory=dict)


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

class SesionIn(BaseModel):
    tipo: str = "individual"  # individual | grupo
    # `modo` es el término del modelo operativo (§3). Si se omite, se toma `tipo`.
    modo: str | None = None  # individual | grupo
    # En modo grupo: ejercicio compartido por todos (cada uno a su nivel).
    ejercicio_compartido_id: str | None = None
    participantes: list[str] = Field(default_factory=list)  # ids usuarios_finales


class SesionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    centro_id: str
    fecha: datetime
    tipo: str
    modo: str
    ejercicio_compartido_id: str | None
    staff_id: str
    cerrada: bool


# ---- Plan de trabajo por paciente ----

class PlanLineaIn(BaseModel):
    tipo: str  # dominio | ejercicio
    bloque: str | None = None  # requerido si tipo == dominio
    ejercicio_id: str | None = None  # requerido si tipo == ejercicio
    nivel: str | None = None  # bajo/medio/alto o entero como str
    n_por_sesion: int = 1
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
    timestamp_inicio: datetime
    timestamp_fin: datetime | None
    valores_json: dict[str, Any]
    cantidad_objetivo_json: dict[str, Any]


class EstadoIntentoIn(BaseModel):
    estado: str  # solo | con_ayuda | no_completado


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
    ultimo_estado: str | None = None
    segundos_desde_ultimo_intento: float | None = None
    atascado: bool = False


class LiveOut(BaseModel):
    sesion_id: str
    tipo: str
    fichas: list[FichaViva]
