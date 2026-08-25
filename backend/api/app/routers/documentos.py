"""Documentos legales/RGPD subidos y guardados EN LA APP (para auditorías): el
centro sube el consentimiento firmado de cada persona, el contrato de encargo
(DPA), el RAT, la DPIA… y quedan disponibles para descargar. Todo scoped por
centro (aislamiento multi-tenant) y auditado. El contenido viaja en base64.
"""
from __future__ import annotations

import base64

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.deps import auditar, get_current_staff, get_db, usuario_del_centro_id
from app.models import TIPOS_DOCUMENTO, DocumentoLegal, UsuarioStaff
from app.schemas import DocumentoContenidoOut, DocumentoIn, DocumentoOut

router = APIRouter(tags=["documentos"])

# Límite por archivo (los escaneos de un folio firmado no pesan más). Evita
# llenar la base de datos y ataques de subida gigante.
_MAX_BYTES = 8 * 1024 * 1024


@router.post("/documentos", response_model=DocumentoOut, status_code=status.HTTP_201_CREATED)
async def subir_documento(
    body: DocumentoIn,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """Sube un documento firmado (consentimiento, DPA, RAT, DPIA…) y lo guarda en
    la app. Si trae `usuario_final_id`, queda ligado a esa persona (debe ser del
    centro). Queda registrado en la auditoría."""
    if body.tipo not in TIPOS_DOCUMENTO:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY,
                            f"tipo inválido (usa: {', '.join(TIPOS_DOCUMENTO)})")
    try:
        crudo = base64.b64decode(body.contenido_b64, validate=True)
    except Exception:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "contenido no es base64 válido")
    if not crudo:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "el documento está vacío")
    if len(crudo) > _MAX_BYTES:
        raise HTTPException(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                            "el documento supera el máximo (8 MB)")
    # Si va ligado a una persona, revalida que sea del centro (anti-IDOR).
    if body.usuario_final_id:
        await usuario_del_centro_id(db, body.usuario_final_id, staff.centro_id)

    doc = DocumentoLegal(
        centro_id=staff.centro_id,
        usuario_final_id=body.usuario_final_id,
        tipo=body.tipo,
        version=body.version,
        nombre_archivo=body.nombre_archivo[:255],
        mime=body.mime[:120],
        tamano=len(crudo),
        contenido_b64=body.contenido_b64,
        subido_por=(staff.nombre or staff.email)[:200],
    )
    db.add(doc)
    await db.flush()
    await auditar(db, staff, "subir_documento",
                  detalle=f"tipo={body.tipo} doc={doc.id} usuario={body.usuario_final_id or '-'}")
    await db.commit()
    await db.refresh(doc)
    return doc


@router.get("/documentos", response_model=list[DocumentoOut])
async def listar_documentos(
    usuario_final_id: str | None = Query(default=None),
    solo_centro: bool = Query(default=False),
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """Lista los documentos del centro (solo metadatos, sin el contenido). Filtra
    por `usuario_final_id`, o `solo_centro=true` para los del centro (DPA/RAT/DPIA)."""
    q = select(DocumentoLegal).where(DocumentoLegal.centro_id == staff.centro_id)
    if usuario_final_id:
        q = q.where(DocumentoLegal.usuario_final_id == usuario_final_id)
    elif solo_centro:
        q = q.where(DocumentoLegal.usuario_final_id.is_(None))
    q = q.order_by(DocumentoLegal.fecha.desc())
    return (await db.execute(q)).scalars().all()


@router.get("/documentos/{doc_id}/contenido", response_model=DocumentoContenidoOut)
async def descargar_documento(
    doc_id: str,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """Descarga el contenido (base64) de un documento del centro. Auditado."""
    doc = await db.get(DocumentoLegal, doc_id)
    if doc is None or doc.centro_id != staff.centro_id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Documento no encontrado")
    await auditar(db, staff, "descargar_documento", detalle=f"doc={doc.id} tipo={doc.tipo}")
    await db.commit()
    return DocumentoContenidoOut(
        id=doc.id, nombre_archivo=doc.nombre_archivo, mime=doc.mime,
        contenido_b64=doc.contenido_b64,
    )


@router.delete("/documentos/{doc_id}", status_code=status.HTTP_204_NO_CONTENT)
async def borrar_documento(
    doc_id: str,
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(get_current_staff),
):
    """Borra un documento (p. ej. subida errónea, o supresión RGPD). Auditado."""
    doc = await db.get(DocumentoLegal, doc_id)
    if doc is None or doc.centro_id != staff.centro_id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Documento no encontrado")
    await auditar(db, staff, "borrar_documento", detalle=f"doc={doc.id} tipo={doc.tipo}")
    await db.delete(doc)
    await db.commit()
