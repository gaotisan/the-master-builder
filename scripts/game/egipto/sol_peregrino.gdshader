shader_type canvas_item;
// El sol de Egipto sobre el peregrino (2026-10-28: iba con la misma luz plana en
// todas partes y parecia puesto encima). Sin tocar sus hojas de sprites:
//  - un borde de luz calida del lado del sol (arriba a la izquierda en el mundo):
//    donde, hacia el sol, al lado ya no hay dibujo. sol_tex: esa direccion en la
//    textura (el script la voltea con flip_h);
//  - el rebote calido de la arena en el bajo de la tunica.
// COLOR ya trae el modulate (la sombra de las repisas lo baja: el borde, con el).
uniform vec2 sol_tex = vec2(-0.7, -0.7);
uniform float borde_px = 6.0;
uniform float borde_fuerza = 0.6;
uniform vec3 color_sol : source_color = vec3(1.0, 0.86, 0.62);
uniform float rebote_fuerza = 0.12;
uniform vec3 color_rebote : source_color = vec3(1.0, 0.72, 0.5);
uniform float rebote_desde = 0.72;   // UV.y de la casilla donde empieza

void fragment() {
	vec4 c = COLOR;
	if (c.a > 0.5) {
		vec2 d = sol_tex * borde_px * TEXTURE_PIXEL_SIZE;
		float fuera = 1.0 - texture(TEXTURE, UV + d).a;
		fuera = max(fuera, 0.6 * (1.0 - texture(TEXTURE, UV + d * 2.0).a));
		vec3 sol = c.rgb + color_sol * borde_fuerza * fuera * max(max(c.r, c.g), 0.35);
		c.rgb = mix(c.rgb, sol, fuera);
		float k = smoothstep(rebote_desde, 1.0, UV.y);
		c.rgb += color_rebote * rebote_fuerza * k * c.rgb;
	}
	COLOR = c;
}
