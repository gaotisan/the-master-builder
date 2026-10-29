shader_type canvas_item;
// EL AGUA DEL FONDO (Acto I de Egipto, 2026-10-26), sobre la capa de la ciudad
// con su rio (la tira): entre 'desde' y 'hasta' (UV.y), sin pasadas aparte.
//   - Los reflejos tiemblan: lo que ya esta pintado en el agua se ondula en
//     horizontal, poco en la otra orilla y mas hacia la de delante (y con ondas
//     mas anchas: estan mas cerca).
//   - Rachas de viento: manchas algo mas oscuras y rizadas que cruzan despacio
//     (un ruido estirado en horizontal que se desplaza).
//   - Destellos: pocos, cortos, y solo sobre los reflejos claros (donde da el sol).

uniform float desde = 0.35;      // UV.y donde empieza el agua (la otra orilla)
uniform float hasta = 1.0;       // y donde acaba (la orilla de delante)
uniform float temblor = 2.2;     // px de vaiven de los reflejos, en la orilla de delante
uniform float rachas = 0.07;     // cuanto oscurecen las rachas
uniform float destellos = 0.35;
uniform sampler2D ruido : repeat_enable, filter_linear;

varying vec4 tinte;
varying vec2 mundo;

void vertex() {
	tinte = COLOR;
	mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float en_agua = smoothstep(desde, desde + 0.004, UV.y) * (1.0 - smoothstep(hasta - 0.004, hasta, UV.y));
	// (fuera del agua queda la imagen tal cual: COLOR ya trae la textura por el
	// tinte; sin esto, todo lo de encima del rio, la ciudad entera, pagaba los
	// senos y las dos lecturas de mas. 2026-10-29, rendimiento)
	if (en_agua > 0.0) {
	float prof = clamp((UV.y - desde) / max(hasta - desde, 0.001), 0.0, 1.0);     // 0 lejos, 1 cerca
	vec2 px = UV / TEXTURE_PIXEL_SIZE;
	// el vaiven: bandas horizontales que se ondulan, mas anchas y mas fuertes cerca
	float periodo = mix(5.0, 16.0, prof);
	float fase = px.y * 6.2832 / periodo + TIME * 1.3 + sin(px.x * 0.004 + TIME * 0.35) * 2.0;
	float dx = sin(fase) * mix(0.4, temblor, prof) * en_agua;
	vec4 c = texture(TEXTURE, UV + vec2(dx * TEXTURE_PIXEL_SIZE.x, 0.0));
	// las rachas: ruido muy estirado en horizontal, en coordenadas del mundo
	vec2 q = vec2(mundo.x * 0.00035 + TIME * 0.006, mundo.y * 0.004 - TIME * 0.002);
	float r = texture(ruido, q).r;
	float racha = smoothstep(0.55, 0.8, r) * en_agua * mix(0.4, 1.0, prof);
	c.rgb *= 1.0 - rachas * racha;
	// los destellos: cortos, sobre lo claro del agua
	float lum = dot(c.rgb, vec3(0.3, 0.55, 0.15));
	float chispa = sin(px.x * 0.22 + TIME * 1.7 + sin(px.y * 0.7) * 3.0) * sin(px.y * 0.9 - TIME * 1.1);
	float brillo = smoothstep(0.93, 1.0, chispa) * smoothstep(0.62, 0.82, lum) * en_agua * (1.0 - racha);
	c.rgb += vec3(1.0, 0.95, 0.85) * brillo * destellos;
	COLOR = c * tinte;  // (no * COLOR: en fragment() ya trae la textura)
	}
}
