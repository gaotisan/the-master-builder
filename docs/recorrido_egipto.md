# Recorrido del Acto I de Egipto (el templo de las terrazas)

El camino que hay hoy hasta el altar y de vuelta, con lo que hace el peregrino en
cada paso, y debajo las reglas del movimiento para montar puzles nuevos sin
tener que redescubrirlas.

Los nombres (c000, c001...) son las cajas de `assets/egipto/acto1/recorrido.json`;
en el juego, **F3** los ensena encima de la piedra y **F4** guarda una marca
(foto + linea en `raw/master_builder/egipto_marcas/marcas.jsonl`). Las alturas
son px del juego sobre la arena; "x" es donde esta la cara o el borde.

## La subida

| de | a | x | altura | como |
|---|---|---|---|---|
| arena | c000 el plinto | -120 | sube 117 | **salto** (andando hacia el, o de parado junto a el) |
| c000 | c001 la pasarela | 312 | baja 72 | **se deja caer** andando (bajo el puente: sin brinco) |
| c001 | c003 el bloque bajo | 690 | sube 67 | **salto** a un escalon, bajo el puente (de parado pegado, o andando desde cerca) |
| c003 | c004 el bloque | 895 | sube 187 | **trepada mediana**: la primera, obligada (no llega de un salto). Andando a la derecha se para contra la cara; saltar |
| c004 | c005 el puente | 848 | sube 187 | **trepada mediana**: andando a la izquierda por c004 (por debajo de la losa) se para en su filo; saltar. La rendija de 47 px entre los dos no es un borde: no se cae por ella |
| c005 | c007 la losa | 881 | sube 162 | **trepada mediana** (o salto): se da la vuelta en el puente y salta contra la losa |
| c007 | c008 el remate | 1162 | sube 173 | **trepada mediana** parado contra la cara (o salto andando: llega justo) |
| c008 | c009 | 1329 | sube 88 | **salto** |
| c009 | c010 | 1509 | sube 68 | **salto** |
| c010 | c011 | 1747 | sube 85 | **salto** |
| c011 | c012 | 1860 | sube 63 | **salto** |
| c012 | c013 la terraza | 2162 | baja 144 | andando, **se deja caer** |
| c013 | c016 el peldanito del altar | 2384 | sube 67 | **salto** (andando o de parado contra el) |
| c016 | c014 el altar | 2436 | sube 173 | **trepada mediana** parado contra el altar (o salto andando: llega justo) |

El peldanito es la piedra con luz pegada al altar (1391-1420 de la imagen; el
altar se pisa desde 1420, el canto de su costado: con 1408 el peldanito era tan
estrecho que el salto no caia encima). La base del obelisco de la izquierda, a su
lado, NO se pisa (el usuario: "se ven como dos piedras, una pegada al altar y otra
que seria la base del obelisco", que esta "se vea que no se puede subir, de
fondo"): esta a la sombra (`retoque_templo.py`, `A_LA_SOMBRA`: la sombra de la
misma piedra en un 0,6 y algo menos de contraste; aplanada del todo era un parche
de color). Antes se pisaba, hecha UN SOLO PELDANO de la
misma piedra del templo (`retoque_templo.py`, `UN_PELDANO`: la cara del peldanito
de arriba, sin su canto, estirada hasta la terraza y tapando entero al de abajo;
la sombra del obelisco se corre fila a fila para que siga con la inclinacion del
fuste: estirada sin mas salia mas empinada y con un quiebro, "queda raro"; dejar
abajo la arena del de abajo volvia a marcar una costura). El usuario: las piezas sueltas eran "un pegote en toda
regla", "lo suyo es que sea un peldano sin escalerita, porque se notan las
costuras". No lleva a ningun otro sitio: es para que se vea que al altar se puede
subir. La base del obelisco de la derecha no se pisa (fondo). (Rechazados, por
este orden: los dos peldanitos dibujados, "lo veo mas como background"; las
piezas sueltas de `Downloads/segundo puzzle egipto`: la escalerita de dos bloques
`kit_arenisca_32`, "hiper basta", tapaba el obelisco; un bloque suelto
`kit_arenisca_23`; la losa con moldura `kit_arenisca_4`, "muy ancha"; el bloque
con la losa volada `kit_arenisca_14` delante de la cara en sombra del altar.)

Arriba del altar (c014) empieza el video del templo (procesion y barco). La
losa del altar no depende del video (el usuario: "son eventos independientes"):
sale siempre que este de pie en el altar, tambien la primera vez, mientras se ve
el video.

## Despues del video: la losa del altar y las ruinas

El puzle de la segunda parte del acto (`scripts/game/egipto/mecanismo_altar.gd`;
los datos en `recorrido.py`, `mecanismo` de `recorrido.json`):

- Al subirse al altar, la tapa del altar (solo la tapa, `SOLO_TAPA`; el cuerpo
  y la placa del escarabajo se quedan) baja 30 px bajo sus pies y la losa larga (`losa_larga`) sale del canto derecho del
  voladizo de la terraza (c013, x 3019, a ras: 980,6) hasta apoyarse en el
  capitel de la columna de las ruinas (c020). La primera vez sale mientras el
  video; al acabar, el peregrino se vuelve a la derecha y la camara la ensena.
- Mientras este de pie en el altar, la losa sale (2,2 s entera) y se queda
  fuera. Al bajarse, vuelve a meterse: empieza parada y coge velocidad
  (`segundos_recoger` 10, de entera a dentro), y la tapa sube con ella.
- **El puzle**: esperar a que salga entera, bajar a la terraza y cruzar
  **corriendo**. Andando no se llega: la punta deja el capitel a los ~5 s y,
  en la losa, se para en la punta (de la losa no se cae al vacio).
- Lo que esta de pie en la losa se va con ella: si no llega, la losa le
  devuelve a la terraza. El filo de la terraza no le deja caer a la arena
  mientras la losa esta fuera, 1,5 s despues de devolverle, ni mientras siga
  con la tecla pulsada (si no, se caia de 981 y tenia que subir otra vez).

| de | a | x | altura | como |
|---|---|---|---|---|
| c013 la terraza | la losa | 3019 | 0 | andando (a ras) |
| la losa | c020 el capitel | punta (~4059) | baja 63 | se deja caer (corriendo, salta a la cornisa) |
| c020 | c021 la cornisa | 4144 | baja 115 | se deja caer |
| c021 | c022 el muro bajo | 4829 | baja 339 | se deja caer |
| c022 | la arena | 6879 | baja 463 | se deja caer andando |

Desde la arena no se sube a las ruinas por ningun lado (la columna, 917; el
muro bajo, 463). Contra la columna se para antes de su zocalo, el bloque de la
base que sobresale 26 px (caja con `zocalo`, `margen_zocalo` 50 en
acciones_egipto.gd; con los 30 de la cara se quedaba metido en el). Del muro bajo a la cornisa (339) si se trepa (la alta): es la
vuelta hacia la losa, si esta fuera. Las ruinas son `muro_columnas` (escala
1,64, la del capitel justo bajo la losa), con dunas en la base, enredaderas,
matas y tres palomas. El hueco de la puerta del muro bajo no se alcanza: es
macizo.

Probar: `egipto_losa.bat` (en el altar, video ya visto); pilotos
`scenes/dev/egipto_losa_correr_bot.tscn` (cruza: `bot: FIN ... y -802`) y
`egipto_losa_andar_bot.tscn` (no cruza y se queda en la terraza:
`y -981`).

## La vuelta

| de | a | x | altura | como |
|---|---|---|---|---|
| c014 el altar | c013 la terraza / c016 | 2818 / 2436 | baja 239 / 173 | se deja caer (a la derecha, a la terraza; a la izquierda, al peldanito y de el a la terraza) |
| c013 | la arena de la derecha | 3019 | baja 981 | **caida de alto** (andando con la tecla: la bajada de flotar; no con la losa fuera) |
| arena | c002 | 3019 | sube 117 | salto |
| c002 | c001 | 1968 | baja 72 | se deja caer |
| c001 | c015 el bloque gemelo | 1482 | sube 67 | salto |
| c015 | c004 | 1275 | sube 187 | trepada mediana (y de ahi, al puente) |
| c004 | c005 el puente | 848 | sube 187 | trepada mediana (de c004 ya no se baja a c003: la rendija es pared) |
| c005 el puente | c004 | 848 | baja 187 | **abajo** en el filo derecho, mirando a el: el saltito de bajar (por donde se sube, se baja; 2026-10-31) |
| c005 | c006 el pilar | 186 | sube 99 | salto |
| c006 | arena | -111 | baja 585 | andando, se deja caer a la arena |

## Fuera del camino

- **El pilar de la izquierda (c006)**: del puente, salto (99); de ahi, a la
  arena de la izquierda (caida de alto). Es la vuelta al principio.
- **c004 ya no sube a la losa** (2026-10-31, el usuario: "por ahi en teoria no
  debe poder escalar": era trepar por la cara del pilar alto). Se sube por el
  puente: la punta izquierda de la losa, que tapaba el extremo del puente, va
  corrida 52 px de la imagen a ras de su capitel (`retoque_templo.py`,
  `CORRIDOS`), y c004 subido 16 px de imagen (`SUBIDAS_TRAS`): de c003 a c004 y
  de c004 al puente, la misma trepada mediana (187). Sin el remate suelto de la
  izquierda de c004 ni la columna de piedrecitas que tenia debajo (salian de
  alargar ese lado en los retoques; "se ven raros"): `CIELOS_TRAS`, y c004
  alargado 12 px a la izquierda estirando su cara de lado (`ESTIRADOS_TRAS`),
  para que la rendija con el puente siga siendo de 47 px. De un dia: al puente se
  subia por su esquina desde debajo, de c003 ("no es nada intuitivo"; quitado).
- **El pilar suelto de la izquierda (c018)**: 815 de alto, no se sube (de fondo).
- **Los tres salientes de encima de la pasarela (c023-c025, 2026-10-31)**: antes
  sin caja; el usuario: "quiero que se puedan usar tb aunque no lleven a ningun
  sitio". Un desvio que vuelve a la base de la derecha:

  | de | a | x | altura | como |
  |---|---|---|---|---|
  | c015 el bloque gemelo | c023 el del medio | 1396 | sube 396 | trepada alta, saltando junto a su canto izquierdo (arista, como c004 -> c005) |
  | c023 | c024 el de abajo | 1756 | baja 144 | se deja caer |
  | c024 | c023 | 1756 | sube 144 | salto |
  | c024 | c025 el alto | 1864 | sube 301 | trepada alta |
  | c025 | c002 | 2069 | baja 547 | se deja caer |

  - El alto, subido 13 px de imagen (`retoque_templo.py`, `SUBIDAS_TRAS`): estaba
    a 277 del de abajo, entre las dos trepadas.
  - De c023 no se trepa al remate del pilar alto (c008, 313): se saltaba media
    subida (`sin_trepar`).
  - c025 acaba a 38 de la terraza (c013): mas que una rendija, no se sube a ella.
  - Por debajo de c024, en la pasarela, se pasa por delante (`despeje` 250), y no
    es techo para el salto a c002 (`sin_techo`). La repisa grande (c010) deja
    rozar la capucha en la punta de c025 (`despeje` 250).
  - Las cajas van con `al_final`: se numeran despues de todas, sin cambiar los
    nombres de las demas.
  - Piloto: `scenes/dev/egipto_salientes_bot.tscn` (de c015 por los tres hasta
    c002: "bot: FIN ... x 2178 y -117").

## Reglas del movimiento (para montar puzles)

Medidas con los videos que hay (no se van a pedir mas de trepar), en px del juego:

| diferencia de altura | que hace |
|---|---|
| hasta 15 | se anda (un peldano) |
| 16 a 52 | **no poner**: ni se anda bien ni se salta ("escalon feo"; `comprobar_trepas` avisa) |
| 53 a 182 | se sube de un **salto**: andando hacia la cara (cae encima) o de parado a menos de 140 sin tecla |
| 150 a 195 | **trepada mediana** parado contra la cara (por encima de 182 es la unica) |
| 196 a 294 | **no poner**: ni se salta ni se trepa (manos en el aire o dentro de la piedra) |
| 295 a 425 | **trepada alta** |
| mas de 425 | no se sube |
| bajar hasta 492 | andando hacia el borde se deja caer (hasta 150 con un brinco corto, salvo bajo techo bajo); parado en el filo con la tecla, el saltito de **bajar** |
| bajar mas de 492 | **caida de alto**: andando con la tecla, la bajada de flotar |

Las repisas (cajas con cara de abajo):

- **Pasar por debajo**: hacen falta 310 px de los pies a la cara de abajo
  (`DESPEJE`; el peregrino mide 305 con la capucha). Con menos, la repisa es una
  pared. Si la repisa esta detras (se pasa por delante de su columna), se le
  puede bajar en su caja (`{"despeje": 290}`, la losa sobre c004: la capucha
  roza su canto).
- **Techo bajo** (menos de 440 libres, `TECHO_SALTO`): no hay salto libre (la
  capucha sube ~430 de parado): la tecla de saltar no hace nada, salvo a un
  escalon de delante al que se llegue sin meter la capucha (como mucho 40 de
  roce) o una cara que se trepe (se para en ella y trepa). De los bordes se deja
  caer sin brinco, tambien corriendo. Medirlo al poner una repisa baja encima del
  camino.
- **Arista** (`{"arista": 1}` o `-1` en la caja de `recorrido.py`): ese canto se
  trepa desde fuera aunque la caja quede por encima de la cabeza; andando se
  sigue pasando por debajo. Es como se sube al puente desde c003. Que el canto
  sea de verdad una esquina libre (con cielo encima y al lado): si es la cara de
  un muro, trepar por ahi no tiene sentido.
- **Rendija** (menos de 52 px, `RENDIJA`: mas estrecha que el peregrino) entre
  dos cajas que estan por encima de lo de debajo: no es un borde por el que
  caer, cuenta como cara (de c004 al puente, del puente a la losa).
- **Bajada** (`{"bajada": 1}` o `-1` en la caja de `recorrido.py`): ese canto da
  a una rendija y, pasada ella, a una pared (el puente, con la losa pegada). Andando
  hacia alli se para en el filo y saltando se trepa a la pared; con **abajo**,
  mirando al filo, baja con el saltito a lo de debajo de mas alla (c004).
  Con la tecla hacia el filo NO baja: el que queria subir a la losa se veia abajo.
- **Corriendo hacia una pared** (Egipto: `frenada_limite_correr` negativo,
  peregrino.gd FRENADA CORRIENDO A LA MEDIDA): frena en la ultima fase del paso que
  casa con la parada y aun cabe; con la tecla, sigue andando lo que falte. Antes,
  con el margen fijo de 380, se paraba hasta 250 px antes.
- **La primera vez que se pide algo, sin alternativa**: la primera trepada
  (c003 -> c004) esta en el unico camino y no llega de un salto; la siguiente
  (c004 -> puente) repite la misma, a la misma altura. Lo nuevo se ensena asi:
  primero obligado y seguro, luego repetido, luego como eleccion.

Lo que no hace:

- **Con el baston en la mano solo anda**: ni corre, ni salta, ni trepa, ni baja
  de los bordes (se para en el filo). Hay que guardarlo para moverse por la
  piedra.
- **Corriendo** salta siempre al pulsar (como en Prince of Persia): si no llega,
  da contra la cara y cae delante. Bajo un techo bajo no salta.

## Piezas sueltas (para montar encima)

Las hojas de `Downloads/segundo puzzle egipto` (copiadas en
`raw/master_builder/referencias/egipto_piezas/`) estan en `tools/egipto/piezas.py`
(`kit_arenisca`, `kit_arenisca_grande`, `kit_banco_muro`, `losa_larga`,
`voladizo`, `muro_columnas`). Se sacan con
`python -I tools/egipto/piezas.py --solo=kit_arenisca` (solo esas: el templo va
retocado) y salen ya con el color de la piedra del templo (`AL_TEMPLO`). Se
colocan en `recorrido.py` (`COLOCADAS`: x, escala y `hundida` negativa para
ponerla encima de algo; `Z` 1 para ir por delante del templo y detras del
peregrino) con sus cajas en `CAJAS` (en px de la pieza, la de abajo en su pie si
esta encima de algo). Las cajas nuevas, al final: no cambian los nombres.

## Como montar o cambiar un tramo

1. Medir las piezas en la imagen y ponerlas en `tools/egipto/recorrido.py`
   (`CAJAS`: `[x0, x1, arriba, abajo]` en px de la imagen; las nuevas, al final
   de su lista, para no cambiar los nombres de las que ya hay).
2. `python -I tools/egipto/recorrido.py --ver` y mirar la lista de trepas: nada
   de "ESCALON FEO" ni "NO SE SUBE" en el camino, y la vista con las cajas sobre
   la piedra.
3. Si una altura no cae en su banda, retocar la piedra (trozos de la misma
   imagen, nunca pintar): `tools/egipto/retoque_templo.py`, y luego
   `Godot --headless --import`.
4. El piloto: `scenes/dev/egipto_zigzag_bot.tscn` (teclas como un jugador, de la
   arena al altar). Headless:
   `Godot_v4.6.2-stable_win64_console.exe --headless --fixed-fps 60 --path . res://scenes/dev/egipto_zigzag_bot.tscn`
   y mirar que acabe en `bot: FIN ... y -1220` sin `ATASCADO`.
5. Las pruebas al azar: `scenes/dev/egipto_azar.tscn` (`semilla`, `segundos`,
   `x_inicio`/`y_inicio` para empezar en un sitio). Teclas al azar, carreras y
   saltos muy seguidos; escribe `RARO ...` (flotando, hundido, dentro de la
   piedra) y `SALTO ... mete N en cXXX` (la capucha en una repisa; ~30 es el
   orbe del baculo, que asoma). Varias semillas a la vez cubren mas.
6. Probarlo jugando (`egipto_acto1.bat`) y, si algo queda raro, F4 en el sitio.
