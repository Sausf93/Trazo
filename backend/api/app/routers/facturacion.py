"""Facturación por suscripción (Stripe).

- El admin de un centro inicia el pago (Checkout) → se abre la pasarela de Stripe.
- Stripe confirma por WEBHOOK cuando el pago se completa o cambia la suscripción,
  y aquí se actualiza el estado del centro (activa / suspendido / cancelada).

La "cantidad" facturada = nº de personas activas del centro (el precio de Stripe
tiene los tramos: 125 € hasta 30, +3 € por cada una de más).

Si Stripe no está configurado (`stripe_secret_key` vacío), los endpoints avisan
en vez de fallar: en dev/tests el cobro queda desactivado.
"""
from __future__ import annotations

import stripe
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.deps import auditar, require_roles
from app.models import Centro, UsuarioFinal, UsuarioStaff
from app.schemas import CheckoutOut

router = APIRouter(tags=["facturacion"])


async def _personas_activas(db: AsyncSession, centro_id: str) -> int:
    n = (await db.execute(
        select(func.count()).select_from(UsuarioFinal)
        .where(UsuarioFinal.centro_id == centro_id, UsuarioFinal.activo.is_(True))
    )).scalar() or 0
    return int(n)


async def sincronizar_cantidad_stripe(db: AsyncSession, centro: Centro | None) -> None:
    """Ajusta la cantidad facturada en Stripe al nº de personas activas del centro,
    para que el cobro por tramos (125 €/30 + 3 €/extra) sea SIEMPRE fiel al uso real.

    Solo actúa si el centro tiene una suscripción de pago ACTIVA (en prueba/cortesía
    no se llama a Stripe: cero coste en el alta/baja normal). Nunca rompe la
    operación de la persona: si Stripe falla, se ignora en silencio."""
    if not settings.stripe_activo or centro is None:
        return
    if centro.estado_suscripcion != "activa" or not centro.stripe_subscription_id:
        return
    try:
        stripe.api_key = settings.stripe_secret_key
        n = max(1, await _personas_activas(db, centro.id))
        sub = stripe.Subscription.retrieve(centro.stripe_subscription_id)
        item = sub["items"]["data"][0]
        if int(item.get("quantity", 0)) != n:
            stripe.SubscriptionItem.modify(
                item["id"], quantity=n, proration_behavior="none")
    except Exception:  # noqa: BLE001 — nunca romper el alta/baja por Stripe
        pass


@router.post("/facturacion/checkout", response_model=CheckoutOut)
async def crear_checkout(
    db: AsyncSession = Depends(get_db),
    staff: UsuarioStaff = Depends(require_roles("admin_centro")),
):
    """Crea una sesión de Stripe Checkout para suscribir a ESTE centro. Devuelve
    la URL a la que redirigir al admin para pagar. La cantidad = personas activas."""
    if not settings.stripe_activo:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE,
                            "El cobro no está configurado todavía.")
    centro = await db.get(Centro, staff.centro_id)
    if centro is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Centro no encontrado")

    stripe.api_key = settings.stripe_secret_key
    cantidad = max(1, await _personas_activas(db, centro.id))
    try:
        sesion = stripe.checkout.Session.create(
            mode="subscription",
            line_items=[{"price": settings.stripe_price_id, "quantity": cantidad}],
            client_reference_id=centro.id,
            customer=centro.stripe_customer_id or None,
            metadata={"centro_id": centro.id},
            subscription_data={"metadata": {"centro_id": centro.id}},
            success_url=f"{settings.panel_url}/cumplimiento?suscripcion=ok",
            cancel_url=f"{settings.panel_url}/cumplimiento?suscripcion=cancelada",
        )
    except Exception as e:  # noqa: BLE001 — error de Stripe → mensaje limpio
        raise HTTPException(status.HTTP_502_BAD_GATEWAY,
                            f"No se pudo iniciar el pago: {e}")
    await auditar(db, staff, "checkout_suscripcion",
                  detalle=f"cantidad={cantidad}")
    return CheckoutOut(url=sesion.url)


def _mapear_estado(status_stripe: str) -> str | None:
    """Traduce el estado de la suscripción de Stripe al del centro."""
    if status_stripe in ("active", "trialing"):
        return "activa"
    if status_stripe in ("past_due", "unpaid", "incomplete_expired"):
        return "suspendido"
    if status_stripe in ("canceled",):
        return "cancelada"
    return None  # incomplete / paused: no tocar


async def _centro_por(db: AsyncSession, *, sub_id=None, cust_id=None, centro_id=None):
    if centro_id:
        c = await db.get(Centro, centro_id)
        if c:
            return c
    stmt = None
    if sub_id:
        stmt = select(Centro).where(Centro.stripe_subscription_id == sub_id)
    elif cust_id:
        stmt = select(Centro).where(Centro.stripe_customer_id == cust_id)
    if stmt is None:
        return None
    return (await db.execute(stmt)).scalars().first()


@router.post("/facturacion/webhook", include_in_schema=False)
async def webhook_stripe(request: Request, db: AsyncSession = Depends(get_db)):
    """Recibe los eventos de Stripe. Verifica la firma y actualiza el estado de
    suscripción del centro. Idempotente: reprocesar un evento no rompe nada."""
    if not settings.stripe_webhook_secret:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "Webhook no configurado")
    payload = await request.body()
    firma = request.headers.get("stripe-signature", "")
    try:
        evento = stripe.Webhook.construct_event(
            payload, firma, settings.stripe_webhook_secret)
    except Exception:  # noqa: BLE001 — firma inválida / payload malformado
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Firma inválida")

    tipo = evento["type"]
    obj = evento["data"]["object"]

    if tipo == "checkout.session.completed":
        centro = await _centro_por(
            db, centro_id=obj.get("client_reference_id")
            or (obj.get("metadata") or {}).get("centro_id"))
        if centro is not None:
            centro.stripe_customer_id = obj.get("customer") or centro.stripe_customer_id
            centro.stripe_subscription_id = obj.get("subscription") or centro.stripe_subscription_id
            centro.estado_suscripcion = "activa"
            await db.commit()

    elif tipo in ("customer.subscription.updated", "customer.subscription.deleted"):
        centro = await _centro_por(
            db, sub_id=obj.get("id"), cust_id=obj.get("customer"),
            centro_id=(obj.get("metadata") or {}).get("centro_id"))
        if centro is not None:
            if tipo.endswith("deleted"):
                nuevo = "cancelada"
            else:
                nuevo = _mapear_estado(obj.get("status", ""))
            if nuevo is not None:
                centro.estado_suscripcion = nuevo
                if obj.get("id"):
                    centro.stripe_subscription_id = obj.get("id")
                await db.commit()

    return {"recibido": True}
