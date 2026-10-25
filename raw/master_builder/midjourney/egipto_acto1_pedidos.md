# Egipto, Acto I — lo que falta en las imágenes

El primer plano del Acto I está montado **solo con recortes** de las imágenes de
referencia 17 a 21 (`fondo_Egipto_plataformas_primer_plano`, las *upscale* de
`--ar 91:51`). Estas piezas no están en ninguna imagen y hoy van provisionales.

Para que encajen con lo que ya hay:

- Usar como referencia de estilo una de las imágenes 17-21: `--sref`, o `--edit`
  como se hicieron ellas.
- Mantener `--ar 91:51 --v 8.2`.
- Para las piezas sueltas, fondo liso de croma: se recortan limpias.

Todos los prompts parten del texto original de las imágenes, que va en la
descripción del PNG.

## 1. La cantera (lo que más falta)

Hoy el último tramo usa ruinas normales.

**1a. Franja de cantera.** Para el final del acto: bloques tallados, rampas,
trineos, cuerdas, piedra trabajada. 2 o 3 imágenes que enlacen entre sí
("extend to the right").

```
Extend the image seamlessly to the right. Preserve the geometric low poly painterly style, color palette, morning lighting and atmosphere. FOREGROUND: True 2D side scrolling platformer plane, orthographic side elevation, camera perfectly perpendicular. An ancient Egyptian limestone QUARRY: stepped quarry benches cut in straight terraces, freshly cut rectangular blocks stacked and half-detached from the bedrock, chisel marks, red ochre guide lines painted on the stone, wooden sledges with a block lashed on top, coiled ropes, wooden levers and wedges in slots, a low earthen ramp seen strictly from the side. One continuous playable route, left to right: horizontal ledges, vertical faces, blocky steps, short climbable walls, small gaps. Platform tops horizontal and nearly edge on. No diagonal depth, no vanishing point paths, no three quarter perspective. Pale warm limestone, a few desert shrubs. BACKGROUND: soft haze. No characters, no text, no UI. --ar 91:51 --v 8.2
```

**1b. La losa.** El gran obstáculo final: un monolito enorme que bloquea el
paso de la cantera. Hoy va un pilar de la 21.

```
A single colossal rectangular limestone slab standing upright, blocking a narrow quarry passage, ancient Egyptian quarry, half-dressed surface with chisel marks, red ochre quarry marks, wooden wedges at its base, a thick rope around it, strict orthographic side elevation, geometric low poly painterly style, warm morning light from the upper left, isolated on a flat solid #00FF00 green background, no characters, no text --ar 2:3 --v 8.2
```

## 2. Piezas que hoy van recompuestas

**2a. El paso bajo.** Hoy es un trozo de muro de la 18 sobre dos pilares de
la 20. Una estructura caída de verdad quedaría mejor.

```
A collapsed stone lintel beam lying across two broken sandstone pillars, forming a low gap underneath that a person must crouch to pass, rubble at the base, ivy and small shrubs, ancient Egyptian ruin, strict orthographic side elevation, 2D platformer foreground piece, geometric low poly painterly style, warm morning light from the upper left, isolated on a flat solid #00FF00 green background, no characters, no text --ar 16:9 --v 8.2
```

**2b. El sillar que se mueve.** Hoy es el pilar de la 20 con una argolla de
pruebas.

```
A single tall rectangular sandstone block with a heavy bronze ring set into its side, slightly worn edges, a few cracks, standing alone, strict orthographic side elevation, geometric low poly painterly style, warm morning light from the upper left, isolated on a flat solid #00FF00 green background, no text --ar 1:2 --v 8.2
```

## 3. Más variedad

Para que no se repitan las mismas franjas, 2 o 3 imágenes más de la familia B.
Mismo prompt original, extendiendo a la derecha desde la 21 y desde la 20.
Sirven sobre todo para el patio (un patio hundido entre muros) y para el muro
largo de correr:

```
Extend the image seamlessly to the right. Preserve the geometric low poly painterly style, color palette, morning lighting, atmosphere, Nile landscape, palms, distant temples, pyramids, and ancient Egyptian architecture. FOREGROUND: True 2D side scrolling platformer plane, orthographic side elevation. A sunken stone courtyard between tall terrace walls, one wall much taller than a person, long horizontal stone ledges, a few loose blocks on the courtyard floor. Platform tops horizontal and nearly edge on. No diagonal depth, no vanishing point paths. BACKGROUND: Preserve natural perspective and atmospheric depth. No characters, no text, no UI. --ar 91:51 --v 8.2
```

## 4. Animaciones del peregrino (Flow)

Hoy están montadas con lo que hay. Las dos son de perfil, mirando a la derecha,
y empiezan y acaban en el reposo del juego. Como en las demás de perfil: báculo
a la espalda, pies vestidos normales, capucha blanda (no picuda) y paso lento y
cansado de viejo, nada de contoneo.

**4a. El mirador.** Hoy: anda hasta el borde y se queda en reposo.

```
Side view, an old hooded pilgrim with a staff strapped on his back stands still on a high stone ledge, then slowly straightens up, lifts his head and looks into the far distance with surprise, takes one small careful step forward, holds the gaze for a moment, and settles back into the same relaxed standing pose as the start. Slow, tired old-man movement. Plain flat background, camera fixed, full body always visible.
```

**4b. La losa que no se mueve.** Hoy: el arranque del empuje v2, unos segundos
de esfuerzo sin avanzar y vuelta atrás.

```
Side view, an old hooded pilgrim with a staff strapped on his back walks up to a huge stone wall, places both palms flat on it and pushes with all his strength, leaning his whole body, feet slipping slightly, the wall does not move at all, he tries twice, then gives up, steps back, catches his breath and returns to the same relaxed standing pose as the start. Plain flat background, camera fixed, full body always visible.
```

## 5. Personajes del fondo (no hay ninguno en las imágenes)

Para meterlos en el fondo con paralaje: la procesión del mirador, campesinos y
pescadores en la orilla, barqueros y canteros. Mejor en hojas de siluetas
pequeñas sobre croma, todas de perfil (izquierda a derecha), con la misma luz
de la mañana.

```
A sheet of small ancient Egyptian figures seen strictly from the side, walking left to right: a funeral procession with a priest, mourning women with raised arms, men pulling a sledge with a sarcophagus, and a standard bearer holding a pole topped with a golden feather; also fishermen with nets, farmers with baskets, a boatman with a long pole. Geometric low poly painterly style, warm morning light from the upper left, each figure separate with space between them, isolated on a flat solid #00FF00 green background, no text --ar 3:1 --v 8.2
```

Y, si se quiere, faluchos sueltos de perfil (los de ahora salen de la imagen
del ribazo y les falta casco):

```
Three ancient Egyptian felucca sailing boats on the Nile seen strictly from the side, triangular lateen sails, wooden hulls, small boatmen, geometric low poly painterly style, warm morning light, each boat separate, isolated on a flat solid #00FF00 green background, no text --ar 3:1 --v 8.2
```
