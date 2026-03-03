# NOTES.md

## Resumen

Implementé una sincronización bidireccional entre la API local de todos y la API externa.

En cada ejecución del sync:

* se obtiene el estado remoto completo con una sola llamada a `GET /todolists`
* se cargan las listas locales con sus items evitando N+1
* se matchean registros por `external_id`, y si falta, por `source_id`
* se aplican solo los cambios necesarios para volver a alinear ambos lados

La solución asume que no hay webhooks, ni una API de deltas, ni un registro remoto de eliminaciones.

## Decisiones principales

La sincronización usa una sola lectura remota por corrida. Eso minimiza llamadas a la API externa y después solo genera escrituras cuando detecta diferencias reales.

Los cambios se detectan comparando `updated_at` con `synced_at`:

* si `updated_at > synced_at`, hubo cambio local
* si el `updated_at` remoto es mayor que `synced_at`, hubo cambio remoto

En caso de conflicto, gana el remoto. Elegí esta regla para mantener el comportamiento simple y determinístico.

La sincronización es incremental siempre que la API externa lo permite:

* renombre de lista: `PATCH /todolists/{id}`
* cambio de item: `PATCH /todolists/{list_id}/todoitems/{item_id}`
* borrado de item: `DELETE /todolists/{list_id}/todoitems/{item_id}`
* borrado de lista: `DELETE /todolists/{id}`

El problema principal del contrato externo es que no existe un endpoint para crear un item dentro de una lista ya existente. Los items solo pueden crearse cuando se crea la lista. Por eso, cuando aparece un item local nuevo dentro de una lista ya sincronizada, el fallback es reconstruir la lista remota: borrar la lista externa y recrearla con todos sus items actuales.

## Eliminaciones locales

Para poder propagar eliminaciones locales de items, agregué soft delete con `deleted_at`.

Cuando un item se elimina localmente, no se borra enseguida de la base. Queda como tombstone, oculto de las queries normales pero conservando su `external_id`. En la siguiente corrida del sync:

1. se detectan esos tombstones
2. se elimina el item en la API externa
3. si la operación remota sale bien, el tombstone se elimina definitivamente de la base

Si el item remoto ya no existe, igual se elimina el tombstone local, porque el estado final deseado ya se cumplió.

## Mapping de datos

El modelo local tiene `title` y `description`, mientras que la API externa solo tiene `description`. Para resolver esa diferencia usé un mapper que transforma:

* local → externo
* externo → local

Así la lógica de transformación queda separada del servicio de sync.

## Resiliencia

El cliente externo reintenta errores transitorios como timeouts, problemas de red y algunas respuestas retryables.

Los errores se aíslan por lista. Si una lista falla durante el sync, las demás siguen procesándose. El resultado devuelve qué registros se sincronizaron bien y cuáles fallaron.

También agregué logs para que los fallos sean fáciles de debuggear, especialmente en errores de la API externa y en el fallback de reconstrucción.

## Trade-offs y limitaciones

El rebuild de una lista remota para agregar items nuevos es más costoso y más riesgoso que el resto del sync, porque depende de un delete + create. No es el path normal: es un fallback impuesto por la limitación de la API externa.

La ejecución del sync quedó sincrónica a propósito, para mantener la solución simple y fácil de testear. En un entorno productivo, el rebuild sería un buen candidato para correr en background con locking y retries.

## Supuestos

* la API externa actualiza `updated_at` en cada cambio
* `source_id` es estable y sirve para recuperar asociaciones si falta `external_id`
* en conflictos, la API externa es la fuente de verdad
* el sistema externo puede devolver items nuevos en listas existentes aunque eso no esté expuesto en el contrato público

## Mejoras futuras

Si tuviera más tiempo, mejoraría estas áreas:

* mover el path de rebuild a un background job
* agregar más protecciones alrededor del fallback delete + recreate
* mejorar el manejo de rate limiting
* soportar creación incremental de items si la API externa agrega ese endpoint en el futuro

## Mejora sugerida a la API externa

La mejora más importante sería agregar un endpoint para crear items dentro de una lista existente, por ejemplo:

`POST /todolists/{id}/todoitems`

Eso eliminaría la necesidad del rebuild y permitiría una sincronización completamente incremental.

## UI y estilos

Para la interfaz usé [Pico CSS](https://picocss.com/) como framework de estilos. Pico aplica estilos directamente sobre HTML semántico (formularios, botones, inputs, tipografía) sin requerir clases utilitarias. Eso permite tener una UI limpia y consistente con muy poco CSS custom (~70 líneas para lo específico de la app: layout de items, botones inline, formulario de agregar item, etc.). Es un buen fit para una app Rails con Turbo porque no necesita un build step de CSS y se integra con un simple link al CDN.

## Cómo correrlo

`bin/rails sync:todos`

o vía HTTP:

`POST /api/sync`
