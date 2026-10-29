shader_type canvas_item;
// LA ORILLA DE ENFRENTE (Acto I de Egipto, 2026-10-27): la tira de palmeras,
// ruinas y cañas recortada, con dos movimientos sin pasadas aparte:
//   - Viento: la vegetacion se mece segun 'viento' (una mascara en gris de
//     tools/egipto/capas.py: hojas si, piedra no, mas cuanto mas alta); rachas
//     lentas que recorren la orilla (el mismo ruido que el agua) y un vaiven
//     con la fase segun donde esta, para que no se muevan todas a la vez.
//   - El reflejo (por debajo de 'costa'): se ondula en horizontal como el agua.

uniform sampler2D viento : filter_linear;
uniform sampler2D ruido : repeat_enable, filter_linear;
uniform float vaiven = 2.6;       // px de textura en lo mas alto de las copas
uniform float costa = 0.51;       // UV.y de la linea del agua
uniform float temblor = 1.6;      // px de vaiven del reflejo

varying vec4 tinte;
varying vec2 mundo;

void vertex() {
	tinte = COLOR;
	mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float m = texture(viento, UV).r;
	// (sin viento y por encima del agua no se mueve nada: la imagen tal cual,
	// que COLOR ya trae por el tinte; asi el cielo vacio y la piedra no pagan
	// el ruido ni los senos. 2026-10-29, rendimiento)
	if (m > 0.0 || UV.y > costa) {
	vec2 px = UV / TEXTURE_PIXEL_SIZE;
	// la racha: un ruido que cruza la orilla despacio (0.4 a 1.4)
	float racha = 0.4 + texture(ruido, vec2(mundo.x * 0.00025 - TIME * 0.018, 0.37)).r * 1.0;
	float fase = mundo.x * 0.011;
	float vai = sin(TIME * 1.15 + fase) * 0.65 + sin(TIME * 2.6 + fase * 1.7 + 1.3) * 0.35;
	float dx = vai * racha * vaiven * m;
	// (y un poco hacia abajo al doblarse: la copa no se estira de lado)
	float dy = abs(vai) * racha * vaiven * m * 0.25;
	// el reflejo
	float en_agua = smoothstep(costa, costa + 0.01, UV.y);
	float prof = clamp((UV.y - costa) / 0.2, 0.0, 1.0);
	float onda = sin(px.y * 6.2832 / mix(4.0, 9.0, prof) + TIME * 1.3 + sin(px.x * 0.004 + TIME * 0.35) * 2.0);
	dx += onda * mix(0.5, temblor, prof) * en_agua;
	vec4 c = texture(TEXTURE, UV - vec2(dx, dy) * TEXTURE_PIXEL_SIZE);
	COLOR = c * tinte;  // (no * COLOR: en fragment() ya trae la textura)
	}
}
