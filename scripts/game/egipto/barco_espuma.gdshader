shader_type canvas_item;
// LA ESPUMA DEL BARCO DEL CORTEJO (Acto I de Egipto, 2026-10-29, el usuario:
// "que se vea un poco mas como se levanta agua ... me da igual si lo sacas del
// video o no"): en un rectangulo a lo largo de la linea del agua del barco
// suelto (TemploRio), en px de la textura del templo.
//   - La raya del casco: espuma rota pegada al casco.
//   - La ola de la proa: un abanico blanco que sube y baja.
//   - La estela: detras de la popa, abriendose y apagandose; quieta en el agua
//     (avance = lo que ha andado el barco).
//   - El remo: salpica al entrar ('salpica', con el fotograma del remo).

uniform sampler2D ruido : repeat_enable, filter_linear;
uniform vec2 tam = vec2(490.0, 24.0);   // el rectangulo
uniform float linea = 6.0;              // y de la linea del agua
uniform float popa = 275.0;             // x donde empieza el casco
uniform float proa = 455.0;
uniform float remo = 268.0;
uniform float avance = 0.0;
uniform float salpica = 0.0;
uniform float fuerza = 1.0;
uniform vec3 color = vec3(0.9, 0.92, 0.9);
// (los faluchos del rio, 2026-10-30: mucho mas lentos, la estela mas corta y la
// ola de la proa mas baja)
uniform float estela_largo = 120.0;
uniform float ola = 1.0;

varying vec4 tinte;

void vertex() {
	tinte = COLOR;
}

float r(vec2 p) {
	return texture(ruido, p).r;
}

void fragment() {
	vec2 p = UV * tam;
	float d = p.y - linea;          // + = hacia abajo, en el agua
	float xa = p.x + avance;        // donde cae en el agua (quieta)
	float a = 0.0;
	// la raya del casco
	float casco = smoothstep(popa - 4.0, popa + 8.0, p.x) * (1.0 - smoothstep(proa - 6.0, proa + 1.0, p.x));
	// (a manchas grandes y blandas: en pantalla 1 px de aqui es medio px, y
	// el ruido fino salia como una raya de puntos)
	// (y tenue y ancha: una raya fina y blanca parecia una linea de puntos)
	a += casco * exp(-(d - 1.0) * (d - 1.0) / 5.0) * smoothstep(0.3, 0.9, r(vec2(xa * 0.008, TIME * 0.03))) * 0.32;
	// la ola de la proa
	vec2 q = vec2((p.x - proa + 4.0) / 14.0, (d + 1.0) / 3.5);
	float sube = 0.75 + 0.25 * sin(TIME * 6.0 + 6.0 * r(vec2(TIME * 0.2, 0.5)));
	a += ola * exp(-dot(q, q)) * sube * smoothstep(0.2, 0.55, r(vec2(p.x * 0.03 - TIME * 0.35, p.y * 0.06)));
	// la estela
	float tras = popa - p.x;
	float abre = 1.5 + tras * 0.03;
	float banda = exp(-pow((d - abre) / (1.4 + tras * 0.02), 2.0));
	a += step(0.0, tras) * exp(-tras / estela_largo) * banda
		* smoothstep(0.4, 0.75, r(vec2(xa * 0.005, d * 0.04 + 0.3))) * 0.7;
	// el remo
	vec2 s = vec2((p.x - remo) / 7.0, (d + 0.5) / 3.5);
	a += salpica * exp(-dot(s, s)) * smoothstep(0.2, 0.55, r(vec2(p.x * 0.04, p.y * 0.05 - TIME * 1.2)));
	COLOR = vec4(color, clamp(a * fuerza, 0.0, 0.85)) * tinte;
}
