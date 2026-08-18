---
title: Vittio revisa que tu estado de cuenta cuadre
slug: vittio-revisa-que-tu-estado-de-cuenta-cuadre
description: Cada vez que subes un estado de cuenta, Vittio hace la misma cuenta que harías tú con una calculadora y te avisa si algo no cierra.
date: 2026-08-17
category: Uso de Vittio
section: guias
published: true
---
Subes tu estado de cuenta, Vittio lo lee, y aparecen 54 movimientos en tu lista. Se ven bien. ¿Y si faltó uno?

Ese es el problema de fondo de cualquier app que lea un PDF por ti: si se le pasa un cargo de 800 pesos, no hay nada raro que ver. La lista se ve completa, los totales se ven razonables, y tu saldo queda mal para siempre sin que nadie se entere.

Por eso Vittio ahora hace una revisión con cada estado de cuenta que subes.

## La cuenta que hace

Tu estado de cuenta trae dos números que tu banco imprime aparte de los movimientos: **con cuánto empezó el periodo** y **con cuánto terminó**. Entre esos dos números están todos tus movimientos, y tienen que cuadrar exactamente:

> Saldo inicial **+** todo lo que entró **−** todo lo que salió **=** saldo final

Es la misma cuenta que harías tú con una calculadora si tuvieras la paciencia. Si Vittio leyó bien tus 54 movimientos, cae exacto en el saldo final que imprimió tu banco. Si se le pasó uno, o leyó 1,800 donde decía 1,300, no cae — y la diferencia es justo lo que falta.

Lo bonito de esto es que no depende de entender qué dice cada movimiento. No importa si tu banco escribe "PAGO SPEI" o "TRANSFERENCIA RECIBIDA" o algo que nunca habíamos visto. Los números cuadran o no cuadran.

## En tu tarjeta de crédito la cuenta va al revés

Una tarjeta no guarda tu dinero, lleva tu deuda. Ahí un cargo **sube** el saldo en lugar de bajarlo, y tu pago lo baja:

> Lo que debías **+** lo que compraste **−** lo que pagaste **=** lo que debes ahora

Vittio ya sabe cuál de las dos cuentas usar según el tipo de cuenta que hayas elegido, así que no tienes que hacer nada.

Una advertencia de la vida real: algunos bancos imprimen **dos** saldos finales. Santander, por ejemplo, pone *"Pago para no generar intereses"* y *"Saldo deudor total"*, y no son lo mismo — el segundo incluye lo que todavía debes de tus compras a meses sin intereses, que aún no te cobran. Vittio usa el primero, que es el que corresponde a este periodo.

## Qué ves si algo no cuadra

Nada, la mayoría de las veces. Si todo cierra, la revisión pasa en silencio y no te enteras. Es la idea.

Cuando no cierra, al abrir el estado de cuenta en la web vas a ver un aviso arriba de la lista:

> **Los movimientos no cuadran con el saldo final**
> Los movimientos de este estado difieren en $800.00 del saldo final que reporta tu banco. Puede que una transacción se haya leído mal o falte alguna. Revisa la lista y corrige lo que no cuadre.

El monto es la pista. Si dice $800.00, busca en tu PDF un movimiento de 800 pesos que no esté en la lista, o uno cuyo monto se haya leído distinto. Casi siempre es una sola línea.

Puedes corregir el monto del movimiento o agregar el que falta, y tu saldo queda bien.

## Qué hacer con el aviso

Lo importante: **el aviso no bloquea nada**. Tu estado de cuenta se subió, tus movimientos están ahí, y puedes seguir usando la app normal. Es una advertencia, no un error.

Tampoco significa que tu banco esté mal. Significa que lo que Vittio leyó del PDF no coincide con lo que tu banco dice, y entre los dos, tu banco tiene la razón.

## En qué cuentas aplica

| Tipo de cuenta | ¿Se revisa? |
|---|---|
| Débito | Sí |
| Crédito | Sí |
| Inversión | No |

Las cuentas de inversión quedan fuera a propósito. El valor que reporta tu casa de bolsa es lo que vale tu portafolio, y eso sube y baja con el mercado sin que haya ningún movimiento que lo explique. No hay forma de llegar a ese número sumando lo que entró y salió, así que revisarlo daría falsas alarmas todo el tiempo. Puedes leer más en [Tus inversiones ya no inflan tus ingresos ni tus gastos](/guides/cuentas-de-inversion-no-son-ingresos-ni-gastos).

También hay estados de cuenta donde el saldo inicial o el final simplemente no vienen, o no se alcanzaron a leer. En esos casos Vittio prefiere no opinar a inventarte una alarma.

## Por qué esto importa

Vittio te dice cuánto ganaste, cuánto gastaste y cuánto tienes. Esos números solo sirven si son ciertos.

Esta revisión es lo que hay atrás de eso: no confiamos en que la lectura del PDF salió bien, la comprobamos contra el propio estado de cuenta. Y cuando no sale, preferimos decírtelo a enseñarte un número bonito que no es el tuyo.
