---
title: "Reglas de categorización: enseña a Vittio una vez y olvídate"
slug: reglas-de-categorizacion
description: Cómo funcionan las reglas de categorización en Vittio, qué significan Contiene, Exacto y Empieza con, y por qué una regla sigue funcionando aunque tu banco escriba el movimiento distinto cada mes.
date: 2026-08-21
category: Uso de Vittio
section: guias
published: true
---
Corriges la categoría de un movimiento, y al mes siguiente el mismo cargo vuelve a llegar mal categorizado. Es de las cosas más molestas de llevar tus finanzas: sientes que estás haciendo el mismo trabajo una y otra vez.

Vittio resuelve eso con **reglas de categorización**. Corriges una vez, Vittio aprende, y a partir de ahí ese movimiento se categoriza solo — en todos los estados de cuenta que subas después.

## Dónde están tus reglas

Entra a **Categorías** en el menú lateral y abre la pestaña **Reglas**.

Las reglas se administran desde la **versión web en computadora**: es una pantalla con tabla,
y en un celular no se alcanza a ver bien. Eso solo aplica a administrarlas. Las reglas se
aplican solas en todos lados — subas el estado de cuenta desde la web o desde la app, tus
movimientos llegan ya categorizados igual.

![Lista de reglas de categorización en Vittio](/blog/reglas-categorizacion-lista.png)

Cada renglón es una regla: el texto que Vittio busca en la descripción del banco, el tipo de coincidencia, la categoría que va a aplicar, cuántas veces la ha usado y si está activa.

## De dónde salen las reglas

La mayoría se crean solas. Cuando cambias la categoría de un movimiento que vino de un estado de cuenta, Vittio guarda esa corrección como regla automáticamente. No tienes que hacer nada más.

También puedes crear una a mano con el botón **Nueva Regla**, que sirve cuando ya sabes de antemano cómo quieres clasificar un cargo:

![Formulario para crear una regla nueva](/blog/reglas-categorizacion-nueva.png)

## Los tres tipos de coincidencia

El **Tipo** decide qué tan estricta es la regla.

### Contiene

El más usado, y el que casi siempre quieres. La regla se aplica cuando las palabras de tu patrón aparecen dentro de la descripción, **en ese orden**, aunque el banco meta algo entre ellas.

Esto importa más de lo que parece. Los bancos rara vez escriben el mismo cargo igual dos meses seguidos: le agregan un número de crédito, una referencia o una sucursal. Por ejemplo, tu banco puede escribir:

- `PAGO DE PRESTAMO 9837815631 TOTAL DE RECIBO`
- `PAGO DE PRESTAMO TOTAL DE RECIBO`

Una regla con el patrón `pago de prestamo total de recibo` reconoce **las dos**. El número de crédito en medio no la rompe.

También funciona al revés, con palabras sueltas: el patrón `oxxo` reconoce `OXXOGAS SUCURSAL 12`.

### Exacto

La descripción tiene que ser idéntica al patrón, sin nada antes ni después. Úsalo cuando un texto muy corto podría confundirse con otro — por ejemplo si tienes dos comercios cuyos nombres se parecen y no quieres que se mezclen.

### Empieza con

La descripción debe empezar con tu patrón. Sirve para bancos que ponen un prefijo fijo al inicio, como `PAGO TARJETA` seguido del número.

## Cuando dos reglas podrían aplicar

Puede pasar que tengas una regla general y otra más específica que encajan en el mismo movimiento:

- `pago de prestamo total de recibo` → Préstamos Personales
- `pago de prestamo 9837815631 total de recibo` → Crédito Automotriz

En ese caso **gana la más específica**, o sea la que tiene el patrón más largo. Así puedes tener una regla general para todos tus préstamos y una excepción para el crédito del coche, sin que se peleen.

## La columna "Usos"

Te dice cuántas veces se ha aplicado esa regla. Una regla recién creada empieza en **0** y va subiendo conforme llegan movimientos que coinciden. Es la forma más rápida de ver si una regla está sirviendo o si nunca ha encajado con nada.

## Reglas y tus deudas y ahorros

Aquí está la parte que más cambia tus números. Si tienes una deuda o una meta de ahorro con **sincronización automática** activada, esta se alimenta de los movimientos de ciertas categorías.

Entonces cuando una regla corrige la categoría de un pago, ese pago también se engancha solo a la deuda correspondiente. Un ejemplo real: el pago mensual de tu crédito automotriz llega, la regla lo manda a *Crédito Automotriz*, y el saldo de tu deuda baja sin que tú hagas nada.

## Desactivar o borrar una regla

Si una regla dejó de servirte, tienes dos opciones en la lista:

- **El interruptor de Activa** la apaga sin borrarla. Deja de aplicarse pero la conservas por si la quieres de vuelta.
- **El bote de basura** la elimina de forma permanente.

Apagar o borrar una regla **no cambia** los movimientos que ya estaban categorizados. Solo afecta lo que venga después.

## Un consejo para que las reglas trabajen a tu favor

No intentes crear todas tus reglas de golpe. Sube tus estados de cuenta normalmente y corrige lo que veas mal. En dos o tres meses vas a tener un juego de reglas hecho a la medida de tus comercios y tus bancos — y casi nada que corregir a mano.

[Empieza gratis, sin tarjeta](/users/new) y sube tu primer estado de cuenta.

## Sigue leyendo

- [Cómo funciona la categorización automática en Vittio](/guides/como-funciona-la-categorizacion-automatica)
- [Cómo subir tu primer estado de cuenta en Vittio](/guides/como-subir-tu-primer-estado-de-cuenta)
- [Cómo seguir tus metas de ahorro y deudas](/guides/como-seguir-metas-de-ahorro-y-deudas)
