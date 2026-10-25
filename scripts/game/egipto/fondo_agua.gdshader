shader_type canvas_item;
// EL AGUA DEL FONDO (capa media del Acto I de Egipto): brillos que corren sobre
// lo que es agua (azulado y claro) de la textura, de 'desde' hacia abajo, sin
// tocar juncos ni palmeras. Sin pasadas aparte: va en el mismo dibujo.

uniform float desde = 0.35;      // en UV: por encima no hay agua
uniform float fuerza = 0.16;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float azul = smoothstep(0.02, 0.10, c.b - c.r) * smoothstep(0.32, 0.55, dot(c.rgb, vec3(0.33)));
	float abajo = smoothstep(desde, desde + 0.05, UV.y);
	// ondas horizontales finas que corren despacio
	float onda = sin(UV.x * 900.0 + TIME * 0.9 + sin(UV.y * 260.0) * 2.0) * sin(UV.x * 237.0 - TIME * 0.6 + UV.y * 80.0);
	float brillo = smoothstep(0.82, 1.0, onda) * azul * abajo;
	c.rgb += vec3(1.0, 0.95, 0.85) * brillo * fuerza;
	COLOR = c * COLOR;
}
