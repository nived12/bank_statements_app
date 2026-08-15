---
title: Tus transferencias entre cuentas ya no cuentan como ingresos
slug: transferencias-entre-tus-cuentas-no-son-ingresos
description: Si pasas dinero de una cuenta tuya a otra, eso no es un ingreso ni un gasto. Vittio ahora detecta esos movimientos con la clave de rastreo del SPEI y los descuenta de tus totales.
date: 2026-08-15
category: Uso de Vittio
section: guias
published: true
---
Imagina que ganas 50,000 pesos al mes. Te los depositan en Santander, y ese mismo día pasas 20,000 a tu cuenta de BBVA para pagar cosas. Al final del mes abres tu app de finanzas y te dice que ganaste 70,000.

No ganaste 70,000. Ganaste 50,000 y moviste una parte de un bolsillo a otro.

Ese error es más común de lo que parece, y crece cada mes: mientras más cuentas tengas y más muevas dinero entre ellas, más inflados quedan tus números. Y no solo el ingreso — el traspaso también aparece como gasto en la cuenta de donde salió. Un solo movimiento ensucia las dos columnas.

Vittio ahora lo resuelve solo.

## Cómo sabe que es la misma transferencia

Cada transferencia SPEI en México trae una **clave de rastreo**: un código único que el Banco de México le asigna a esa operación. Lo importante es que *los dos bancos imprimen la misma clave* — el que envía y el que recibe.

Cuando subes los estados de cuenta de ambas cuentas, Vittio compara esas claves. Si coinciden, no hay duda: es el mismo dinero, visto desde los dos lados. Vittio lo marca como transferencia y lo saca de tus ingresos y de tus gastos.

Esto importa porque los bancos casi nunca coinciden en la fecha. BBVA suele registrar la fecha en que hiciste la operación y Santander la fecha en que la aplicó — dos o tres días después. Antes eso hacía imposible emparejarlas automáticamente. Con la clave de rastreo la fecha deja de importar.

## Cuando no hay clave, Vittio te pregunta

No todos los movimientos traen clave. Los traspasos entre cuentas del mismo banco, o el pago de tu tarjeta de crédito, muchas veces no la tienen.

En esos casos Vittio busca parejas por monto y fecha, pero **no adivina**. Si encuentra dos movimientos que podrían ser la misma transferencia, te los muestra para que tú decidas. Preferimos preguntarte una vez al mes que equivocarnos en silencio: si Vittio uniera dos movimientos que en realidad no tienen nada que ver, borraría un gasto real y un ingreso real de tus totales, y nunca te enterarías.

### En la app: deslizas y listo

En la app te aparece un botón con el número de transferencias por revisar arriba de tus transacciones. Al abrirlo ves una tarjeta por cada pareja: el monto, las dos cuentas, las dos fechas y qué tan separadas están.

- Desliza a la **derecha** para confirmar que sí es una transferencia tuya.
- Desliza a la **izquierda** para descartarla.
- ¿Te equivocaste? El botón **Deshacer** regresa la última tarjeta.

Nada se guarda hasta que terminas la última. Si cierras la pantalla a medias, no pasa nada: las parejas siguen ahí esperándote.

### En la web: una lista para revisar

En la versión web entras a **Transacciones** y verás el enlace de candidatos por revisar. Ahí aparece la lista con las dos cuentas, el monto y la diferencia de días. Marcas las que sí son transferencias, y las demás se quedan como están.

## También detecta cargos que se cancelan solos

Hay otro caso que inflaba los números sin que nadie se diera cuenta: cuando difieres una compra a **meses sin intereses**, tu banco cancela el cargo original y lo vuelve a cobrar en parcialidades. En el estado de cuenta eso aparece como un "abono" — y un abono parece un ingreso.

No lo es. Es tu propia compra devolviéndose para cobrarse de otra forma. Lo mismo pasa con devoluciones y con pagos con puntos.

Vittio ahora reconoce esas parejas — un cargo y el abono que lo cancela por el mismo monto — y las deja fuera de tus totales. Siguen apareciendo en tu lista de movimientos, marcadas como canceladas, para que veas que existieron. Simplemente ya no cuentan como dinero que ganaste ni como dinero que gastaste.

## Qué significa esto para ti

Tus totales de ingresos y gastos se acercan mucho más a la realidad. En una cuenta real que revisamos, el ingreso de un mes bajó de 216,000 a 146,000 pesos — y esos 70,000 de diferencia nunca fueron ingresos: eran traspasos entre cuentas propias y compras diferidas a meses.

Para aprovecharlo:

1. **Sube los estados de cuenta de todas tus cuentas**, no solo una. Vittio solo puede emparejar una transferencia si ve los dos lados.
2. **Revisa el botón de transferencias** cuando aparezca. Son pocas y toma menos de un minuto.
3. Si ves un movimiento entre cuentas tuyas que Vittio no detectó, puedes marcarlo como transferencia desde el detalle del movimiento.

Y si tienes una cuenta que todavía no está en Vittio — una de inversión, una de nómina vieja — vale la pena agregarla. Cada cuenta que falta es una transferencia que no se puede emparejar.
