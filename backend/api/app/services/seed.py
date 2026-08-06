"""Siembra de datos de demo (idempotente).

Crea un centro, staff con login, participantes pseudonimizados, un ejercicio por
cada uno de los 8 bloques (sobre el motor de plantillas) y algunos intentos de
ejemplo — incluyendo una tendencia a la baja que dispara una alerta, para que el
panel se vea con vida desde el primer arranque.

Credenciales de demo:
    admin@trazo.local        / trazo1234   (admin_centro)
    integradora@trazo.local  / trazo1234   (integradora)
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import (
    Centro,
    DatosIdentificativos,
    Dispositivo,
    EjercicioCatalogo,
    Intento,
    PlanPacienteLinea,
    Sesion,
    SesionParticipante,
    UsuarioFinal,
    UsuarioStaff,
)
from app.security import hash_password
from app.services.alertas import evaluar_usuario_bloque

PASSWORD_DEMO = "trazo1234"


def _ejercicios_semilla() -> list[dict]:
    """Un ejercicio funcional por cada bloque, sobre las 8 plantillas."""
    return [
        {
            "bloque": "atencion_memoria",
            "plantilla_tipo": "memoria_visual",
            "nombre": "Memoria de figuras",
            "descripcion": "Mira unas figuras, desaparecen, y localízalas entre varias.",
            "parametros_json": {
                "recordar_min": 2, "recordar_max": 5, "segundos": 60,
                "banco": [
                    {"id": "estrella", "label": "estrella"},
                    {"id": "corazon", "label": "corazón"},
                    {"id": "luna", "label": "luna"},
                    {"id": "sol", "label": "sol"},
                    {"id": "flor", "label": "flor"},
                    {"id": "arbol", "label": "árbol"},
                    {"id": "casa", "label": "casa"},
                    {"id": "coche", "label": "coche"},
                ],
            },
        },
        {
            "bloque": "lenguaje",
            "plantilla_tipo": "evocacion_libre",
            "nombre": "Objetos por categoría",
            "descripcion": "Di objetos que haya en un sitio concreto. Validación por la integradora.",
            "parametros_json": {
                "pedir_min": 5, "pedir_max": 10,
                "prompts": [
                    {"texto": "objetos que haya en la cocina"},
                    {"texto": "cosas que se puedan comprar en una frutería"},
                    {"texto": "animales de granja"},
                ],
            },
        },
        {
            "bloque": "razonamiento",
            "plantilla_tipo": "seleccion_multiple",
            "nombre": "El intruso",
            "descripcion": "Varios objetos; uno no pertenece al grupo.",
            "parametros_json": {
                "opciones_min": 4, "opciones_max": 5,
                "items": [
                    {"id": "frutas", "instruccion": "¿Cuál no es una fruta?",
                     "correcta": "zapato", "distractores": ["manzana", "pera", "plátano", "naranja"]},
                    {"id": "animales", "instruccion": "¿Cuál no es un animal?",
                     "correcta": "silla", "distractores": ["perro", "gato", "vaca", "caballo"]},
                ],
            },
        },
        {
            "bloque": "gnosias",
            "plantilla_tipo": "seleccion_multiple",
            "nombre": "Reconocer la emoción",
            "descripcion": "Una cara con una expresión; elegir la emoción correcta.",
            "parametros_json": {
                "opciones_min": 3, "opciones_max": 4,
                "items": [
                    {"id": "alegria", "instruccion": "¿Qué emoción muestra esta cara?",
                     "imagen": "cara_alegria", "correcta": "alegría",
                     "distractores": ["tristeza", "sorpresa", "enfado"]},
                    {"id": "tristeza", "instruccion": "¿Qué emoción muestra esta cara?",
                     "imagen": "cara_tristeza", "correcta": "tristeza",
                     "distractores": ["alegría", "sorpresa", "miedo"]},
                ],
            },
        },
        {
            "bloque": "praxias",
            "plantilla_tipo": "trazo",
            "nombre": "Sigue la línea",
            "descripcion": "Grafomotricidad: seguir un trazo con el dedo.",
            "parametros_json": {
                "instruccion": "Sigue la línea con el dedo",
                "tolerancia_px": 24, "viewbox": "0 0 300 140",
                "figuras": [
                    {"id": "onda", "path": "M20,100 Q90,20 150,80 T280,60"},
                    {"id": "arco", "path": "M20,110 Q150,10 280,110"},
                    {"id": "ese", "path": "M40,30 C120,30 60,110 140,110 C220,110 160,30 260,30"},
                ],
            },
        },
        {
            "bloque": "percepcion",
            "plantilla_tipo": "conteo_comparacion",
            "nombre": "¿Cuál tiene más?",
            "descripcion": "Dos grupos de objetos; señalar cuál tiene más.",
            "parametros_json": {
                "modo": "cual_tiene_mas", "cantidad_min": 2, "cantidad_max": 9,
                "objetos": ["manzana_roja", "manzana_verde"],
            },
        },
        {
            "bloque": "funcion_ejecutiva",
            "plantilla_tipo": "secuencia_ordenar",
            "nombre": "Ordenar los pasos de una tarea",
            "descripcion": "Poner en orden los pasos de una rutina conocida.",
            "parametros_json": {
                "pasos_min": 3, "pasos_max": 4,
                "tareas": [
                    {"id": "camisa", "titulo": "Lavar una camisa",
                     "pasos": ["Lavar", "Tender", "Planchar", "Guardar"]},
                    {"id": "vestirse", "titulo": "Ponerse el zapato",
                     "pasos": ["Poner el calcetín", "Poner el zapato", "Atar el cordón"]},
                ],
            },
        },
        {
            "bloque": "vida_cotidiana",
            "plantilla_tipo": "manejo_cantidad",
            "nombre": "Manejo de dinero",
            "descripcion": "Juntar una cantidad con monedas. Cantidades cambiantes.",
            "parametros_json": {
                "modo": "dinero", "total_min": 5, "total_max": 12,
                "monedas": [1, 2, 5],
            },
        },
    ]


async def sembrar(db: AsyncSession) -> None:
    existe = (await db.execute(select(Centro).limit(1))).scalars().first()
    if existe is not None:
        return  # ya sembrado

    ahora = datetime.now(timezone.utc)

    centro = Centro(nombre="Centro de Día Demo")
    db.add(centro)
    await db.flush()

    db.add_all([
        UsuarioStaff(centro_id=centro.id, nombre="Marta (dirección)", rol="admin_centro",
                     email="admin@trazo.local", password_hash=hash_password(PASSWORD_DEMO)),
        UsuarioStaff(centro_id=centro.id, nombre="Laura", rol="integradora",
                     email="integradora@trazo.local", password_hash=hash_password(PASSWORD_DEMO)),
    ])
    staff_integradora = None
    await db.flush()
    staff_integradora = (
        await db.execute(select(UsuarioStaff).where(UsuarioStaff.rol == "integradora"))
    ).scalars().first()

    # Participantes: el alias es el nombre de pila (lo que ve el equipo para
    # reconocer a la persona); el nombre COMPLETO va en la tabla separada
    # restringida. Los dos primeros llevan historial (para el panel); el resto
    # son solo altas, para que el desplegable de reparto se vea realista.
    roster = [
        ("Paco", "Francisco Gómez Ruiz"),
        ("Marisa", "María Luisa Herrero Díaz"),
        ("Carmen", "Carmen Ortiz Vidal"),
        ("Juan", "Juan López Serrano"),
        ("Lola", "Dolores Martín Cano"),
        ("Pepe", "José Antonio Ramírez"),
        ("Rosa", "Rosa Fernández Gil"),
        ("Antonio", "Antonio Navarro Peña"),
    ]
    participantes: list[UsuarioFinal] = []
    for alias, nombre_real in roster:
        uf = UsuarioFinal(centro_id=centro.id, alias_interno=alias, nivel_base_json={})
        db.add(uf)
        await db.flush()
        db.add(DatosIdentificativos(usuario_final_id=uf.id, nombre_real=nombre_real))
        participantes.append(uf)

    # Ejercicios (uno por bloque).
    ejercicios: dict[str, EjercicioCatalogo] = {}
    for cfg in _ejercicios_semilla():
        ej = EjercicioCatalogo(**cfg)
        db.add(ej)
        await db.flush()
        ejercicios[cfg["bloque"]] = ej

    await db.flush()

    # --- Intentos de demo para dar vida al panel ---
    # Paquito: praxias con tendencia clara a la baja -> debe disparar alerta.
    # Marisa: praxias estable/al alza -> sin alerta.
    ej_praxias = ejercicios["praxias"]

    def _crear_sesion_e_intento(uf, ej, dias_atras, precision, estado="solo"):
        fecha = ahora - timedelta(days=dias_atras)
        ses = Sesion(centro_id=centro.id, fecha=fecha, tipo="individual",
                     staff_id=staff_integradora.id, cerrada=True)
        db.add(ses)
        return ses, fecha

    # Series de precisión (de más antiguo a más reciente).
    serie_paquito = [0.86, 0.88, 0.90, 0.89, 0.91, 0.90, 0.62, 0.55]  # cae al final
    serie_marisa = [0.70, 0.72, 0.74, 0.76, 0.78, 0.80, 0.82, 0.85]   # mejora

    for uf, serie in [(participantes[0], serie_paquito), (participantes[1], serie_marisa)]:
        n = len(serie)
        for idx, prec in enumerate(serie):
            dias = (n - idx) * 5  # una sesión cada ~5 días
            fecha = ahora - timedelta(days=dias)
            ses = Sesion(centro_id=centro.id, fecha=fecha, tipo="individual",
                         staff_id=staff_integradora.id, cerrada=True)
            db.add(ses)
            await db.flush()
            db.add(SesionParticipante(sesion_id=ses.id, usuario_final_id=uf.id))
            db.add(Intento(
                usuario_final_id=uf.id, sesion_id=ses.id, ejercicio_id=ej_praxias.id,
                timestamp_inicio=fecha, timestamp_fin=fecha + timedelta(minutes=2),
                estado="solo",
                valores_json={"precision": prec, "tiempo_ms": 90000},
                cantidad_objetivo_json={"figura_id": "onda", "tolerancia_px": 24},
            ))

    await db.flush()

    # --- Planes de trabajo de demo (formato mixto por dominio) ---
    # Paco: praxias (bajo) + atención/memoria (medio). Marisa: lenguaje.
    paco, marisa = participantes[0], participantes[1]
    db.add_all([
        PlanPacienteLinea(usuario_final_id=paco.id, tipo="dominio",
                          bloque="praxias", nivel="bajo", n_por_sesion=2, orden=0),
        PlanPacienteLinea(usuario_final_id=paco.id, tipo="dominio",
                          bloque="atencion_memoria", nivel="medio", n_por_sesion=1, orden=1),
        PlanPacienteLinea(usuario_final_id=marisa.id, tipo="dominio",
                          bloque="lenguaje", nivel="medio", n_por_sesion=2, orden=0),
    ])

    # --- Dispositivos emparejados de demo (1 maestra + 2 participantes) ---
    db.add_all([
        Dispositivo(centro_id=centro.id, nombre="Tablet maestra (Laura)", rol="maestra"),
        Dispositivo(centro_id=centro.id, nombre="Tablet participante 1", rol="participante"),
        Dispositivo(centro_id=centro.id, nombre="Tablet participante 2", rol="participante"),
    ])

    await db.flush()

    # Evaluar alertas sobre los datos sembrados.
    for uf in participantes:
        await evaluar_usuario_bloque(db, uf.id, "praxias")

    await db.commit()
