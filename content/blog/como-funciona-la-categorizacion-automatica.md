---
title: Cómo funciona la categorización automática en Vittio
slug: como-funciona-la-categorizacion-automatica
description: Cómo Vittio categoriza automáticamente tus movimientos bancarios con IA, qué categorías reconoce y cómo crear reglas para que aprenda de tus correcciones.
date: 2026-06-17
category: Uso de Vittio
section: guias
published: true
---
Cuando subes un estado de cuenta a Vittio, la IA lee cada movimiento y lo asigna a una categoría — comida, transporte, servicios, entretenimiento, y más de 130 subcategorías. No tienes que etiquetar nada a mano.

Esta guía explica cómo funciona ese proceso, qué categorías reconoce y cómo enseñarle a Vittio tus preferencias con reglas automáticas.

## Qué pasa cuando subes un PDF

1. Vittio detecta el banco y el tipo de cuenta del PDF.
2. La IA extrae cada movimiento: fecha, descripción, monto y tipo (cargo o abono).
3. Cada movimiento se asigna a una categoría basándose en el nombre del comercio y la descripción del banco.
4. Los resultados aparecen en tu dashboard en unos 30 segundos.

No necesitas configurar categorías manualmente — Vittio ya tiene más de 130 predefinidas, pensadas para comercios mexicanos.

## Categorías que Vittio reconoce

Vittio entiende comercios y servicios comunes en México, por ejemplo:

- **Comida:** Oxxo, Rappi, Uber Eats, Costco, Sam's Club, supermercados.
- **Transporte:** Uber, DiDi, gasolineras (Pemex, BP, Shell), estacionamientos.
- **Servicios:** CFE, Telmex, Totalplay, Izzi, agua.
- **Entretenimiento:** Netflix, Spotify, Disney+, Cinépolis, Steam.
- **Compras:** Liverpool, Amazon, Mercado Libre, SHEIN.
- **Salud:** farmacias (Farmacias del Ahorro, Guadalajara, San Pablo).
- **Finanzas:** comisiones bancarias, anualidad de tarjeta, intereses.

En total, Vittio cubre 14 categorías padre y más de 120 subcategorías — verificado directamente en la base de datos de producción.

## Reglas automáticas: enseña a Vittio una vez

Si la IA categoriza un movimiento de forma incorrecta, puedes corregirlo manualmente. Cuando lo haces, Vittio te ofrece crear una **regla automática**: "siempre que aparezca este comercio, usa esta categoría".

A partir de ese momento, todos los movimientos futuros de ese comercio se categorizan automáticamente con la categoría que elegiste — sin que tengas que corregir de nuevo.

Ejemplo: si Vittio categoriza "PAGO OXXO 4521" como "Compras" y tú lo cambias a "Comida rápida", la regla hace que todos los Oxxo futuros vayan directo a "Comida rápida".

## Cambiar la categoría de un movimiento

Abre el movimiento y toca **Categoría** — o, en la lista de transacciones de la app, desliza el
movimiento hacia la derecha y toca **Categorizar**.

Se abre el buscador con todas tus categorías y subcategorías. Escribe las primeras letras
(*"tarje"*, *"gasol"*) y aparecen solo las que coinciden, así no tienes que recorrer la lista
completa para llegar a una subcategoría como *Tarjetas de Crédito* o *Préstamos Personales*.
También puedes dejar el movimiento **Sin categoría** si prefieres decidir después.

## Detección de pagos recurrentes

Además de categorizar, Vittio detecta movimientos que se repiten mes a mes: suscripciones (Netflix, Spotify), servicios (CFE, internet), mensualidades y pagos fijos. Esto te permite ver de un vistazo cuánto gastas en cosas recurrentes — y detectar suscripciones que ya no usas.

## Categorización en el plan Gratis vs Premium

- **Premium:** categorización automática al subir un PDF, reglas automáticas y detección de recurrentes.
- **Gratis:** puedes categorizar manualmente cada transacción, pero la IA no procesa el PDF automáticamente.

La categorización automática es función Premium — incluida en los 30 días de prueba gratis al crear tu cuenta.

[Empieza gratis, sin tarjeta](/users/new) y sube tu primer estado de cuenta para ver la categorización en acción.

## Sigue leyendo

- [Cómo subir tu primer estado de cuenta en Vittio](/guides/como-subir-tu-primer-estado-de-cuenta)
- [Cancelar suscripciones que no usas](/blog/cancelar-suscripciones-que-no-usas)
- [En qué se va mi dinero: cómo saberlo de verdad](/blog/como-saber-en-que-gasto-mi-dinero)

## Fuentes

- Número de categorías verificado directamente en la base de datos de producción de Vittio (junio de 2026)
