# Cómo marcar fallos del recorrido de piedra (Egipto, Acto I)

Las marcas guardan la posición **del juego**, no de la pantalla: valen igual en
cualquier resolución o monitor.

## Las dos teclas

| Tecla | Qué hace |
|---|---|
| **F3** | Enseña / oculta lo que se pisa: cada caja en rojo, con su **borde de arriba en verde** (donde apoyan los pies) y su nombre (`c004`, `c007`...). Un **punto amarillo** en los pies del peregrino y una raya amarilla a la altura de su cabeza. Arriba a la izquierda: `x`, `altura`, la caja que pisa y la animación. |
| **F4** | Guarda una **marca**: la captura de pantalla con las cajas dibujadas y los datos exactos. Sale el aviso "Marca N guardada". |

Las marcas se guardan en esta misma carpeta:
- `marca_01.png`, `marca_02.png`... (la captura)
- `marcas.jsonl` (una línea por marca: sitio, caja, estado, animación, fotograma)

## Ejemplo práctico

1. Lanza `egipto_acto1.bat` y juega normal.
2. Trepas al bloque bajo y ves que **los pies se quedan flotando** sobre la piedra.
3. Sin moverte, pulsa **F4**. Sale "Marca 1 guardada".
4. Sigues. Llegas al puente y **no te deja trepar** donde crees que debería.
5. Ponte justo donde querías trepar, mirando hacia allí, y pulsa **F4**: "Marca 2 guardada".
6. Si quieres ver por qué, pulsa **F3**: verás si ahí hay borde verde (se pisa) o no.
7. Al acabar, escríbeme algo así:

   > marca 1: flota sobre el bloque, los pies tienen que bajar
   > marca 2: aquí debería poder trepar al puente
   > marca 3: esta columna parece que se puede pisar y no se puede

Con eso sé exactamente el sitio, la caja y lo que hacía el peregrino.

## Consejos

- Marca **en el momento**: quieto, justo donde pasa el fallo.
- Si el fallo es durante un salto o una trepa, pulsa F4 a mitad: guarda el fotograma.
- Una marca por fallo; el número sigue aunque cierres el juego.
- Para empezar de cero, borra esta carpeta (menos este archivo).
