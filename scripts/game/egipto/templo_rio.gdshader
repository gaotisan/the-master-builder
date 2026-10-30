shader_type canvas_item;
// EL TEMPLO DEL CORTEJO (Acto I de Egipto, 2026-10-29): el video del usuario
// (o su primer / ultimo fotograma) sobre croma verde, en la orilla de enfrente.
//   - El croma fuera (lo mismo que tools/egipto/templo_rio.py) y sin el verde
//     que sobra en los bordes.
//   - El color de la orilla: la piedra del video con la luz y el color de la de
//     la tira (en Lab), llevado a una matriz de color (templo.json "grado"),
//     con el velo de la calima en las sombras ("velo") y un poco suavizado,
//     como la pintura de la orilla.
//   - reflejo = true: el mismo dibujo boca abajo (el sprite con flip_v), como
//     los reflejos pintados de la orilla: corrido en vertical (manchas, sin el
//     dibujo de las palmeras), con su misma onda, el agua asomando entre medias
//     y apagandose hacia abajo. (Un espejo nitido y con el color "del agua"
//     medido quedaba salmon y pegado, 2026-10-29.)

uniform mat3 grado = mat3(1.0);
uniform vec3 grado_add = vec3(0.0);
uniform bool reflejo = false;
uniform float temblor = 0.7;        // px de textura de vaiven del reflejo, abajo del todo (con 1,6 como la orilla vibraba: sus bordes son duros)
uniform float largo = 0.75;         // hasta donde llega el reflejo (fraccion del alto)
uniform float corrido = 16.0;       // px de textura que se corre en vertical, abajo del todo
uniform float opaco = 0.78;         // lo que tapa el reflejo al agua, junto a la orilla
uniform float sombra = 1.12;        // el reflejo, algo mas claro (el sol en el agua, como los de la orilla)
uniform float suave = 1.0;          // px de textura del suavizado del templo
// (los px de arriba, medidos con el video a 640 de ancho: px de la textura por
// cada uno; templo.json "px". El suavizado no: con el video entero, la mitad en
// pantalla, que a 1,4 se veia blando junto a la orilla)
uniform float px = 1.0;
// LO QUE SE MUEVE UN POCO (2026-10-29, el usuario: las banderas "de vez en cuando",
// la vela, el barquero "demasiado quieto"; "algo sutil que de el pego sin rehacer
// animaciones"): mascara del tamano de la textura (templo_rio.py mascaras_mueve).
// R: tela colgada que ondea de lado (la bandera), a rachas; G: tela que se hincha
// (el toldo, la vela), con su sombra; B: alguien de pie que se mece y respira (el
// barquero). Px de 640 de ancho, como lo de arriba.
uniform sampler2D mueve : filter_linear, hint_default_black;
uniform bool con_mueve = false;
// el velo de la calima (templo.json "velo"): las sombras del templo iban mucho
// mas oscuras y con mas contraste que la orilla pintada; mezclado un poco hacia
// el color del aire de lejos, sombras y medios caen donde los de la orilla sin
// torcer el tono (una curva por canal lo dejaba rosado, 2026-10-29)
uniform vec3 velo_color = vec3(0.67, 0.76, 0.78);
uniform float velo = 0.0;
// EL RELEVO SIN SALTO (2026-10-30, el barco del remo limpio): el fotograma del
// barco de antes (el del video del templo, mismo tamano que la textura) y cuanto
// se ve de el (1 = ese entero, 0 = el de la textura); se mezcla px a px.
uniform sampler2D antes : filter_linear, hint_default_transparent;
uniform float antes_peso = 0.0;

varying vec4 tinte;

void vertex() {
	tinte = COLOR;
}

// (premultiplicado: el croma no tine lo que se corre)
vec4 muestra(sampler2D t, vec2 uv) {
	vec4 c = texture(t, uv);
	float verde = c.g - max(c.r, c.b);
	float a = c.a * (1.0 - clamp((verde * 255.0 - 25.0) / 70.0, 0.0, 1.0));
	c.g = min(c.g, max(c.r, c.b) + 6.0 / 255.0);
	return vec4(c.rgb * a, a);
}

// (premultiplicado: donde los dos tapan, siempre tapa; sin croma el de antes, y
// no por muestra(): Godot no deja pasarle TEXTURE y un uniform a la vez)
vec4 dibujo(sampler2D t, vec2 uv) {
	vec4 c = muestra(t, uv);
	if (antes_peso <= 0.0) {
		return c;
	}
	vec4 a = texture(antes, uv);
	return mix(c, vec4(a.rgb * a.a, a.a), antes_peso);
}

void fragment() {
	vec4 c;
	if (reflejo) {
		// (con flip_v, UV.y = 1 en la linea del agua)
		float prof = 1.0 - UV.y;
		vec2 t = TEXTURE_PIXEL_SIZE * px;
		vec2 p = UV / t;
		vec2 uv = UV;
		// (la misma onda que los reflejos de orilla.gdshader, mas floja, y
		// corrido tambien unos px de lado: los reflejos pintados de la orilla son
		// blandos y apenas cambian al ondularse; este, con los bordes de las
		// palmeras, vibraba. Medido: ahora cambia lo mismo que la orilla)
		float onda = sin(p.y * 6.2832 / mix(4.0, 9.0, prof) + TIME * 1.3 + sin(p.x * 0.004 + TIME * 0.35) * 2.0);
		uv.x += onda * mix(0.3, temblor, prof) * t.x;
		float h = mix(3.0, corrido, prof) * t.y;
		c = vec4(0.0);
		for (int i = -4; i <= 4; i++) {
			float k = float(i) / 4.0;
			vec2 d = vec2(sin(float(i) * 2.3) * 3.0 * t.x, k * h);
			c += dibujo(TEXTURE, uv + d) * (1.0 - 0.5 * abs(k));
		}
		// (los pesos suman 6,5)
		c /= 6.5;
		c.rgb = c.a > 0.001 ? c.rgb / c.a : vec3(0.0);
		c.a *= opaco * (1.0 - smoothstep(largo * 0.2, largo, prof));
	} else {
		vec2 uv = UV;
		float luz = 1.0;
		if (con_mueve) {
			vec4 m = texture(mueve, UV);
			vec2 p = UV / (TEXTURE_PIXEL_SIZE * px);
			float t = TIME;
			// (las rachas: casi quieto y de vez en cuando un rato de viento)
			float racha = 0.25 + 0.75 * smoothstep(0.45, 0.9, 0.5 + 0.5 * sin(t * 0.29) * sin(t * 0.17 + 1.3));
			vec2 d = vec2(0.0);
			d.x += m.r * racha * 1.3 * sin(t * 2.4 - p.y * 0.12);
			float hincha = sin(t * 1.05 + p.y * 0.035 + p.x * 0.015);
			d += m.g * (0.5 + 0.5 * racha) * vec2(0.7 * hincha, 0.45 * sin(t * 0.85 + p.x * 0.03));
			luz += m.g * 0.035 * sin(t * 1.05 + p.y * 0.035 + p.x * 0.015 + 0.9);
			d.x += m.b * (0.5 * sin(t * 0.7) + 0.2 * m.b * sin(t * 1.9 + 0.7));
			d.y += m.b * 0.25 * (0.5 + 0.5 * sin(t * 1.3));
			uv -= d * px * TEXTURE_PIXEL_SIZE;
		}
		// (un poco suavizado: el video trae el doble de detalle que la pintura
		// de la orilla y resaltaba)
		vec2 s = suave * TEXTURE_PIXEL_SIZE;
		c = dibujo(TEXTURE, uv) * 0.4
			+ (dibujo(TEXTURE, uv + s) + dibujo(TEXTURE, uv - s)
			+ dibujo(TEXTURE, uv + vec2(s.x, -s.y)) + dibujo(TEXTURE, uv + vec2(-s.x, s.y))) * 0.15;
		c.rgb = c.a > 0.001 ? c.rgb / c.a * luz : vec3(0.0);
	}
	vec3 rgb = mix(grado * c.rgb + grado_add, velo_color, velo);
	if (reflejo) {
		rgb *= sombra;
	}
	// (* tinte y no * COLOR: en fragment() COLOR ya trae la textura)
	COLOR = vec4(clamp(rgb, 0.0, 1.0), c.a) * tinte;
}
