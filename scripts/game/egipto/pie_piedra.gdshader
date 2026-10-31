shader_type canvas_item;
// La luz de las piezas del recorrido (egipto_acto1.gd):
//  - el pie: algo mas oscuro en la banda de abajo, hasta la linea donde la corta
//    la arena de delante (la oclusion del suelo);
//  - LO QUE SE PISA, A LA VISTA (2026-10-28; el usuario no veia que se podia
//    pisar): los cantos de las repisas (cajas[], en UV: x0, x1, y de arriba,
//    alto del canto) con su luz y un filo calido arriba; lo demas de la pieza
//    (los muros de detras), algo mas apagado y frio. Solo luz sobre el dibujo.
uniform float suelo_uv = 1.0;   // y (UV) de la linea donde la corta la arena
uniform float banda_uv = 0.1;   // alto de la banda (UV)
uniform float fuerza = 0.3;
uniform vec4 cajas[24];
uniform int n_cajas = 0;
uniform float fondo = 0.86;      // la luz de lo que no se pisa
uniform float filo = 0.12;       // lo que se aviva el filo de arriba
uniform float filo_uv = 0.006;   // su alto (UV)
uniform float canto_suave = 0.01; // (UV) la transicion del canto al muro
// EL ALTAR QUE SE HUNDE (2026-10-31, mecanismo_altar.gd): dos rectangulos (UV:
// x0, y0, x1, y1) con la silueta del altar; 1 = el templo sin ellos, 2 = solo
// ellos (el altar recortado, que baja por detras del templo); 0 = nada.
uniform int hueco_modo = 0;
uniform vec4 hueco_a;
uniform vec4 hueco_b;

bool en_rect(vec2 uv, vec4 r) {
	return uv.x >= r.x && uv.x < r.z && uv.y >= r.y && uv.y < r.w;
}

void fragment() {
	// (COLOR ya trae la textura por el modulate: no volver a multiplicarla)
	vec4 c = COLOR;
	if (hueco_modo != 0) {
		bool dentro = en_rect(UV, hueco_a) || en_rect(UV, hueco_b);
		if (dentro == (hueco_modo == 1)) {
			c.a = 0.0;
		}
	}
	// (lo transparente de la pieza, sin el bucle de las cajas: no cambia nada y
	// es mucho del rectangulo del templo; 2026-10-29, rendimiento)
	if (n_cajas > 0 && c.a > 0.0) {
		float canto = 0.0;
		float arriba = 0.0;
		for (int i = 0; i < n_cajas; i++) {
			vec4 k = cajas[i];
			float dx = min(UV.x - k.x, k.y - UV.x);
			if (dx < 0.0) continue;
			float bajo = UV.y - k.z;          // lo que baja desde la cara de arriba
			if (bajo < -0.002) continue;
			float en = 1.0 - smoothstep(k.w, k.w + canto_suave, bajo);
			en *= smoothstep(0.0, 0.004, dx);
			canto = max(canto, en);
			arriba = max(arriba, (1.0 - smoothstep(0.0, filo_uv, bajo)) * smoothstep(0.0, 0.004, dx));
		}
		float l = mix(fondo, 1.0, canto);
		vec3 frio = vec3(0.97, 0.99, 1.04);
		c.rgb *= mix(vec3(l) * frio, vec3(1.0), canto);
		c.rgb += c.rgb * filo * arriba * vec3(1.0, 0.92, 0.78);
	}
	float f = clamp((UV.y - (suelo_uv - banda_uv)) / banda_uv, 0.0, 1.0);
	f = f * f * f;
	c.rgb *= 1.0 - fuerza * f;
	COLOR = c;
}
