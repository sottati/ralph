# PRD: Ajustes Integrales Presupuestos, Órdenes de Trabajo, Stock y Facturación (PromoGraph ERP)

## Resumen

- Se detectó el skill `write-a-prd` y se usó su estructura para este PRD.
- Objetivo: convertir tus notas de reunión del 25/02 en especificación cerrada, separada por tareas, sin priorización.
- Resultado esperado: flujo comercial/operativo consistente desde presupuesto hasta cierre de orden, con stock correcto (incluyendo ml y placas PVC), nueva lógica de facturación y mejoras de UX/PDF.

## Problem Statement

Hoy hay inconsistencias funcionales y de UX que impactan operación real:

- Nomenclatura mixta en OT (Orden/Nota/NT).
- Consumo real al finalizar OT no resuelve correctamente todos los casos (ml, merma).
- La OT no refleja demasía en dimensiones operativas.
- Remito se genera desde presupuesto y no desde el cierre operativo.
- Punto de venta depende del presupuesto, no del usuario.
- Mano de obra y logística están unificadas en un solo campo.
- Tabla de presupuestos sin fecha visible.
- Facturación modelada como booleano, insuficiente para el circuito administrativo requerido.
- Falta material eventual en presupuestos.
- Versionado no muestra “mismo número + versiones”.
- OT sin progreso visual por unidad producida.
- Stickers requiere lógica comercial específica (laca/fondo blanco +10% c/u).
- Falta tratamiento de placas PVC por placa completa 1.22x2.44.

## Solution

Implementar un paquete funcional por tareas (sin prioridad) que:

1. Unifica lenguaje y visual de “Orden de Trabajo” en toda UI con identificador visible `OT-`.
2. Corrige el cierre de OT para consumo real por unidad de medida, registrando merma explícita.
3. Genera OT con dimensiones que ya incluyen demasía.
4. Mueve remito al flujo de OT finalizada (detalle de OT).
5. Asigna punto de venta fijo por usuario (autocompleta y bloquea; excepción manual si usuario no tiene PV asignado).
6. Separa Mano de Obra y Logística y mantiene markup sobre subtotal completo.
7. Agrega fecha en tabla de presupuestos.
8. Reemplaza facturado booleano por estado administrativo de 4 valores.
9. Habilita material eventual ad-hoc sin alta en catálogo y sin impacto de stock.
10. Implementa versionado visible “número raíz + vN” para nuevas versiones.
11. Agrega checklist visual de progreso en OT y atomización de ítems con cantidad >1.
12. Añade lógica sticker (laca/fondo blanco) sólo para categoría Stickers.
13. Ajusta PDF de presupuesto/remito manteniendo estilo actual y reservando espacio para logo.

## User Stories

1. Como admin, quiero que toda la UI diga “Orden de Trabajo”, para evitar confusión operativa.
2. Como operario, quiero ver `OT-###` en lugar de `NT-###`, para identificar órdenes en forma consistente.
3. Como operario, quiero finalizar una OT cargando consumo real por ítem consumible, para descontar stock real.
4. Como operario, quiero registrar merma (real vs teórico), para auditar pérdidas.
5. Como admin, quiero que materiales `ml` descuente en `ml`, para no distorsionar inventario.
6. Como taller, quiero que OT muestre medidas con demasía incluida, para producir con medidas correctas.
7. Como administración, quiero emitir remito sólo desde OT finalizada, para alinear documento con ejecución real.
8. Como admin, quiero definir un punto de venta fijo por usuario, para evitar errores fiscales de carga.
9. Como usuario sin PV asignado, quiero poder cargar PV manualmente, para no bloquear operación.
10. Como vendedor, quiero separar Mano de Obra y Logística, para reflejar costos reales.
11. Como vendedor, quiero que markup se aplique sobre materiales + mano de obra + logística, para mantener criterio comercial acordado.
12. Como usuario, quiero ver fecha en tabla de presupuestos, para ordenar y auditar rápidamente.
13. Como administración, quiero 4 estados de facturación, para modelar el circuito real.
14. Como admin, quiero poder pasar de cualquier estado de facturación a cualquier otro, para correcciones rápidas.
15. Como sistema, quiero iniciar presupuestos en “X blanca”, para reflejar estado inicial administrativo.
16. Como vendedor, quiero agregar material eventual no catalogado, para cotizar casos excepcionales.
17. Como sistema, quiero que material eventual no afecte stock, para no contaminar inventario.
18. Como usuario, quiero versionar presupuestos con mismo número raíz y sufijo vN, para trazabilidad clara con cliente.
19. Como sistema, quiero aplicar el nuevo versionado sólo a versiones nuevas, para no romper histórico.
20. Como operario, quiero tildar ítems ya producidos, para visualizar progreso de trabajo.
21. Como operario, quiero atomizar ítems con cantidad >1 en sub-ítems editables, para cargar datos por unidad.
22. Como administración, quiero cálculo de PVC por placa completa (1.22x2.44), para costeo y stock correctos.
23. Como vendedor, quiero que laca y fondo blanco sumen 10% cada uno en stickers, para cotizar correctamente.
24. Como usuario, quiero mantener estética actual de PDF/remito pero con espacio de logo, para futura identidad visual.

## Backlog Narrativo (Referencia)

### Tarea 1: Nomenclatura consistente de Orden de Trabajo

- Cambiar todos los labels UI de “Nota de trabajo/NT” a “Orden de Trabajo/OT”.
- Identificador visible estándar: `OT-{incrementalId}`.
- Mantener identificadores internos técnicos sin cambios obligatorios.

### Tarea 2: Cierre OT con consumo real y merma (m2/ml)

- En finalización, capturar por ítem: consumo teórico, consumo real y merma.
- Validar consumo real numérico >= 0.
- Aplicar descuento de stock según unidad del material (`m2` o `ml`).
- Guardar auditoría de consumos y merma por ítem.

### Tarea 3: OT con demasía incorporada

- Al emitir OT desde presupuesto, calcular dimensiones operativas ya con demasía.
- Mostrar esas dimensiones en vista de OT y usarlas como base teórica de consumo.

### Tarea 4: Remito sólo desde OT finalizada

- Eliminar acción de remito en presupuesto.
- Mostrar acción de remito en detalle de OT cuando estado = finalizada.
- Mantener generación PDF de remito existente, cambiando punto de entrada del flujo.

### Tarea 5: PV fijo por usuario

- Agregar PV fijo en perfil de usuario.
- En presupuesto: autocompletar desde usuario y bloquear edición.
- Excepción: si usuario no tiene PV fijo, habilitar carga manual.

### Tarea 6: Separar Mano de Obra y Logística

- Reemplazar campo único por dos campos.
- Cálculo: markup sobre subtotal completo (materiales + mano de obra + logística).
- Resumen total muestra líneas separadas + subtotal neto + IVA + total.

### Tarea 7: Fecha en tabla de presupuestos

- Agregar columna de fecha visible (emisión/creación).
- Mantener ordenado por fecha descendente como default.

### Tarea 8: Facturación en 4 estados

- Nuevo estado administrativo: `x_blanca`, `x_negra`, `no_facturado`, `facturado`.
- Estado inicial: `x_blanca`.
- Transiciones: cualquiera a cualquiera.
- Badge debe mostrar “X” para estados X (color blanco/negro) y texto para facturado/no facturado.

### Tarea 9: Material eventual en presupuesto

- Permitir ítems ad-hoc con nombre, unidad, precio y cantidad sin material del catálogo.
- Esos ítems computan en costos/totales.
- No generan movimientos de stock.

### Tarea 10: Versionado visible “número raíz + vN”

- Preservar un número raíz común para la cadena de versiones.
- Mostrar formato `#<raíz> vN`.
- Aplicar sólo a nuevas versiones.
- Histórico actual no se migra.

### Tarea 11: Progreso OT + atomización por cantidad

- Si cantidad >1, expandir a sub-ítems editables por unidad.
- Cada sub-ítem tiene estado de progreso (hecho/no hecho).
- El progreso es visual/operativo (no bloquea finalización por defecto).

### Tarea 12: Stickers con laca/fondo blanco

- Categoría Stickers en materiales.
- En ítems Stickers: checkboxes `laca` y `fondo_blanco`.
- Recargo: +10% por cada checkbox activo (acumulable +20%).

### Tarea 13: PVC placas 1.22x2.44 por placa entera

- Definir materiales tipo placa PVC.
- Cálculo de placas: `ceil(area_total_con_demasia / (1.22 * 2.44))`.
- Costeo y stock en cantidad de placas completas.

### Tarea 14: PDF presupuesto/remito con slot de logo

- Mantener estilo actual.
- Agregar placeholder fijo para logo (casi cuadrado, levemente horizontal).
- Fallback textual si no hay logo configurado.

## Cambios de Interfaces Públicas / Tipos

- Presupuesto:
  - Reemplazo de `facturado: boolean` por `billingStatus: BillingStatus4`.
  - Separación `laborCost` y `logisticsCost`.
  - Soporte de ítems eventuales (sin `materialId` obligatorio).
  - Metadatos de versión visible (número raíz + versión).
- Usuario:
  - Nuevo campo de perfil: `fixedPuntoVenta`.
- OT:
  - Datos de finalización con `theoretical`, `real`, `waste`, `unit`.
  - Soporte de sub-ítems atomizados y progreso por sub-ítem.
- Material/Ítem comercial:
  - Flags sticker por ítem: `hasLaca`, `hasFondoBlanco`.
  - Regla de material tipo placa PVC con dimensiones fijas de placa.

## Testing Decisions

- Criterio de buena prueba:
  - Validar comportamiento observable (cálculos, transiciones, permisos, salida UI/PDF), no detalles internos.
- Cobertura mínima por módulo:
  - Facturación 4 estados: creación con `x_blanca`, transición libre, render de badge.
  - Cierre OT: validación consumo real, cálculo merma, descuento correcto por unidad.
  - Demasía OT: emisión con medidas operativas correctas.
  - PVC placas: cálculo de placas por `ceil` y totales.
  - Material eventual: impacto en total sin impacto en stock.
  - Versionado: nuevas versiones con número raíz + `vN`.
  - Stickers: recargos 10%/20% según checks.
  - PV fijo: autocompletar/bloquear y excepción manual sin PV.
  - Remito: ausencia en presupuesto y presencia en OT finalizada.
  - Checklist/atomización: persistencia de estado por sub-ítem.
  - PDF: render de placeholder de logo y fallback.
- Pruebas de regresión:
  - Crear/editar presupuesto estándar sin stickers/eventual.
  - Flujo OT clásico (pendiente → producción → finalizado).
  - Cálculo de IVA/total sin desvíos.

## Tareas

### T01: Nomenclatura consistente de Orden de Trabajo
- Risk: low
- Status: pending

#### Acceptance Criteria
- [ ] Toda referencia visible de "Nota de trabajo/NT" se muestra como "Orden de Trabajo/OT".
- [ ] El identificador visible se renderiza como `OT-{incrementalId}`.
- [ ] No se cambian identificadores internos técnicos.

#### Test Targets
- Render de labels de OT en vistas principales.
- Render de identificador visible en listados y detalle.

#### Notes
- Alcance solo UI/identificador visible.

### T02: Cierre OT con consumo real y merma (m2/ml)
- Risk: high
- Status: done

#### Acceptance Criteria
- [x] Al finalizar OT se capturan `theoretical`, `real`, `waste` y `unit` por ítem.
- [x] `real` se valida como numérico y `>= 0`.
- [x] El descuento de stock respeta unidad (`m2` o `ml`).
- [x] Se persiste auditoría de consumo real y merma por ítem.

#### Test Targets
- Validación de input de consumo real.
- Descuento de stock por unidad correcta.
- Persistencia de datos de auditoría.

#### Notes
- No ejecutar migraciones en producción.

### T03: OT con demasía incorporada
- Risk: medium
- Status: pending

#### Acceptance Criteria
- [ ] Al emitir OT, dimensiones operativas incluyen demasía.
- [ ] Vista OT muestra dimensiones con demasía.
- [ ] Consumo teórico usa esas dimensiones como base.

#### Test Targets
- Cálculo de dimensiones operativas.
- Render de dimensiones en detalle de OT.

#### Notes
- Mantener compatibilidad con flujo OT actual.

### T04: Remito solo desde OT finalizada
- Risk: medium
- Status: pending

#### Acceptance Criteria
- [ ] No existe acción de remito en presupuesto.
- [ ] Existe acción de remito en detalle OT con estado finalizada.
- [ ] Se mantiene el PDF actual de remito, cambia solo el punto de entrada.

#### Test Targets
- Visibilidad condicional de acción remito.
- Flujo de generación PDF desde OT finalizada.

#### Notes
- No rediseñar template PDF.

### T05: Punto de venta fijo por usuario
- Risk: high
- Status: done

#### Acceptance Criteria
- [x] Usuario soporta campo `fixedPuntoVenta`.
- [x] Presupuesto autocompleta PV desde usuario y bloquea edición si existe.
- [x] Si usuario no tiene PV fijo, permite carga manual.

#### Test Targets
- Regla de autocompletar/bloquear PV.
- Excepción manual cuando falta PV fijo.

#### Notes
- Debe evitar bloqueo operativo para usuarios sin PV.

### T06: Separar Mano de Obra y Logística
- Risk: medium
- Status: pending

#### Acceptance Criteria
- [ ] Campo único se reemplaza por `laborCost` y `logisticsCost`.
- [ ] Markup aplica sobre materiales + mano de obra + logística.
- [ ] Resumen muestra líneas separadas, subtotal neto, IVA y total.

#### Test Targets
- Cálculo de markup sobre subtotal completo.
- Render de breakdown de totales.

#### Notes
- Mantener cálculo fiscal actual de IVA.

### T07: Fecha en tabla de presupuestos
- Risk: low
- Status: pending

#### Acceptance Criteria
- [ ] Tabla muestra columna de fecha (emisión/creación).
- [ ] Orden default sigue fecha descendente.

#### Test Targets
- Render de columna fecha.
- Ordenamiento default descendente.

#### Notes
- No cambiar filtros existentes.

### T08: Facturación en 4 estados
- Risk: high
- Status: in_progress

#### Acceptance Criteria
- [ ] Reemplazo de `facturado:boolean` por `billingStatus` con 4 estados.
- [ ] Estado inicial en nuevos presupuestos: `x_blanca`.
- [ ] Transiciones permitidas entre cualquier par de estados.
- [ ] Badge muestra `X` para estados X y texto para facturado/no_facturado.

#### Test Targets
- Creación con estado inicial correcto.
- Transiciones libres.
- Render del badge por estado.

#### Notes
- Preservar lecturas de datos históricos durante transición.

### T09: Material eventual en presupuesto
- Risk: high
- Status: blocked

#### Acceptance Criteria
- [ ] Presupuesto permite ítems ad-hoc sin `materialId`.
- [ ] Ítems eventuales computan en costos/totales.
- [ ] Ítems eventuales no generan movimientos de stock.

#### Test Targets
- Cálculo de total con material eventual.
- Verificación de ausencia de impacto en stock.

#### Notes
- Mantener UX clara para distinguir ítem eventual de catálogo.
- Blocked: `bun run lint` falla por errores globales preexistentes fuera de T09.

### T10: Versionado visible numero raiz + vN
- Risk: high
- Status: pending

#### Acceptance Criteria
- [ ] Nuevas versiones preservan número raíz común.
- [ ] Formato visible: `#<raiz> vN`.
- [ ] Regla aplica solo a versiones nuevas.
- [ ] No se migra histórico existente.

#### Test Targets
- Generación secuencial de versiones nuevas.
- Render de formato visible en listados/detalle.

#### Notes
- Compatibilidad temporal obligatoria.

### T11: Progreso OT y atomizacion por cantidad
- Risk: high
- Status: pending

#### Acceptance Criteria
- [ ] Ítems con cantidad > 1 se expanden en sub-ítems por unidad.
- [ ] Cada sub-ítem tiene estado de progreso hecho/no hecho.
- [ ] El progreso visual no bloquea finalización por defecto.

#### Test Targets
- Atomización por cantidad.
- Persistencia de progreso por sub-ítem.

#### Notes
- Mantener simple el flujo del operario.

### T12: Stickers con laca y fondo blanco
- Risk: medium
- Status: pending

#### Acceptance Criteria
- [ ] Categoría Stickers disponible en materiales.
- [ ] Ítems Sticker muestran checkboxes `laca` y `fondo_blanco`.
- [ ] Recargo de +10% por cada checkbox activo (hasta +20%).

#### Test Targets
- Cálculo de recargo 0/10/20%.
- Visibilidad condicional de checkboxes para Stickers.

#### Notes
- Regla aplica solo a categoría Stickers.

### T13: PVC por placa completa 1.22x2.44
- Risk: high
- Status: pending

#### Acceptance Criteria
- [ ] Material PVC placa se calcula por placa completa.
- [ ] Cantidad de placas = `ceil(area_total_con_demasia / 2.9768)`.
- [ ] Costeo y stock usan cantidad de placas completas.

#### Test Targets
- Cálculo por `ceil` con casos de borde.
- Impacto en costo total y descuento de stock.

#### Notes
- Usar factor fijo 2.9768 m2 por placa.

### T14: PDF presupuesto/remito con slot de logo
- Risk: medium
- Status: pending

#### Acceptance Criteria
- [ ] Se mantiene estilo visual actual del PDF.
- [ ] Se agrega placeholder fijo para logo.
- [ ] Si no hay logo configurado, renderiza fallback textual.

#### Test Targets
- Render de placeholder y fallback.
- Regresión visual básica del layout actual.

#### Notes
- No rediseño completo de PDF.

## Ralph Execution Rules

1. Trabajar exactamente una tarea por iteración.
2. Selección de tarea:
   - solo `Status: pending`
   - prioridad por `Risk` (`high > medium > low`)
   - empate por ID ascendente (`T01`, `T02`, ...)
3. Aplicar TDD vertical slice (RED -> GREEN repetible).
4. Correr `bun run lint && bun run test:run` antes de cerrar tarea.
5. Cerrar tarea (`Status: done`) solo si checks pasan y criterios están cubiertos.
6. Si checks fallan: no cerrar tarea; mantener `in_progress` o pasar a `blocked` con motivo.
7. No modificar estado/checklist de tareas no seleccionadas.

## Out of Scope

- Deploy, operaciones de infraestructura o cambios en Vercel.
- Migraciones ejecutadas contra producción.
- Rediseño visual completo del sistema (se mantiene estilo actual).
- Reescritura de históricos previos al nuevo esquema de versionado.

## Further Notes

- El backlog narrativo se mantiene sin prioridad estricta; la ejecución AFK usa `Risk` + ID para selección.
- Todas las migraciones quedan planteadas como artefactos SQL/TS versionables.
- Se recomienda mantener compatibilidad temporal de lecturas mientras conviven datos viejos/nuevos en transición.
- Si se desea, el siguiente paso es derivar este PRD a tickets de implementación 1:1 por tarea.

## Supuestos y Defaults Confirmados

- Formato: 1 PRD integral.
- Renombre OT: alcance UI + identificador visible `OT-`.
- Remito: sólo desde OT finalizada (detalle).
- ml: consumo real manual.
- Merma: se guarda explícitamente.
- Demasía: OT usa dimensiones con demasía.
- Versionado: número raíz + `vN`, sólo nuevas versiones.
- Material eventual: ad-hoc, sin stock.
- Stickers: recargo sólo en categoría Stickers.
- Facturación: 4 estados, default `X blanca`, transición libre.
- PV por usuario: fijo y bloqueado; si falta PV fijo, manual.
- PVC: placas por `ceil(area_total / 2.9768)`.
- PDF: mantener estética actual + placeholder de logo con fallback.
