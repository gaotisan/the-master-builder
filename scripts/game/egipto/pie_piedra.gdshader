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

void fragment() {
	// (COLOR ya trae la textura por el modulate: no volver a multiplicarla)
	vec4 c = COLOR;
	if (n_cajas > 0) {
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
