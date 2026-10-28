shader_type canvas_item;
// La piedra del recorrido junto a la arena (egipto_acto1.gd, PIE_BANDA): mas
// oscura y algo mas fria en la banda de abajo, hasta la linea del suelo.
uniform float suelo_uv = 1.0;   // y (UV) de la linea de la arena
uniform float banda_uv = 0.1;   // alto de la banda (UV)
uniform float fuerza = 0.3;

void fragment() {
	// (COLOR ya trae la textura por el modulate: no volver a multiplicarla)
	vec4 c = COLOR;
	float f = clamp((UV.y - (suelo_uv - banda_uv)) / banda_uv, 0.0, 1.0);
	f *= f;
	c.rgb *= 1.0 - fuerza * f;
	c.rgb = mix(c.rgb, c.rgb * vec3(0.92, 0.97, 1.08), f);
	COLOR = c;
}
