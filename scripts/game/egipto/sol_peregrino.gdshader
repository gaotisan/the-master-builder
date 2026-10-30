shader_type canvas_item;
// El sol de Egipto sobre el peregrino (2026-10-28: iba con la misma luz plana en
// todas partes y parecia puesto encima). Sin tocar sus hojas de sprites:
//  - un borde de luz calida del lado del sol (arriba a la izquierda en el mundo):
//    donde, hacia el sol, al lado ya no hay dibujo. sol_mundo: esa direccion en el
//    mundo; en la textura, volteada si el sprite lo esta (flip_h: la textura
//    avanza al reves en la pantalla). Antes la volteaba el script con flip_h y
//    llegaba un fotograma tarde: al acabar cada giro, un fotograma con el borde
//    en la espalda (2026-10-30, el usuario: "al final vibra como que se aposenta");
//  - el rebote calido de la arena en el bajo de la tunica.
// COLOR ya trae el modulate (la sombra de las repisas lo baja: el borde, con el).
uniform vec2 sol_mundo = vec2(-0.75, -0.65);
uniform float borde_px = 6.0;
uniform float borde_fuerza = 0.6;
uniform vec3 color_sol : source_color = vec3(1.0, 0.86, 0.62);
uniform float rebote_fuerza = 0.12;
uniform vec3 color_rebote : source_color = vec3(1.0, 0.72, 0.5);
uniform float rebote_desde = 0.72;   // UV.y de la casilla donde empieza

void fragment() {
	vec4 c = COLOR;
	// (fuera del if: las derivadas, en todo el bloque de pixeles)
	float lado = dFdx(UV.x) < 0.0 ? -1.0 : 1.0;
	if (c.a > 0.5) {
		vec2 d = vec2(sol_mundo.x * lado, sol_mundo.y) * borde_px * TEXTURE_PIXEL_SIZE;
		float fuera = 1.0 - texture(TEXTURE, UV + d).a;
		fuera = max(fuera, 0.6 * (1.0 - texture(TEXTURE, UV + d * 2.0).a));
		vec3 sol = c.rgb + color_sol * borde_fuerza * fuera * max(max(c.r, c.g), 0.35);
		c.rgb = mix(c.rgb, sol, fuera);
		float k = smoothstep(rebote_desde, 1.0, UV.y);
		c.rgb += color_rebote * rebote_fuerza * k * c.rgb;
	}
	COLOR = c;
}
