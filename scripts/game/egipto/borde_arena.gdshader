shader_type canvas_item;
// La arena de delante (egipto_acto1.gd, _montar_tira), donde toca las piezas del
// recorrido (2026-10-28, el usuario: el pie del templo "no esta bien definido,
// no queda real"):
//  - su borde de arriba, nitido. capas.py la funde con la de detras con una
//    rampa de 26 px (son la misma imagen: sin piezas en medio no hay costura);
//    delante de la piedra emborronaba su pie. Solo en las primeras filas
//    (hasta_uv): lo plantado en la arena conserva sus filos.
//  - sin las franjas de sombra azul de arriba (las de la imagen de la playa):
//    pegadas al pie de la piedra parecian un canal de agua. Se deshace el tinte
//    (lo azul pasa al color de la arena con su misma variacion de luz) hasta
//    sin_sombra_uv, y se funde de vuelta abajo.
uniform float hasta_uv = 0.045;
uniform float desde_a = 0.7;
uniform float hasta_a = 0.95;
uniform float sin_sombra_uv = 0.14;
// (para la arena de detras: la franja de UV donde se limpia, y sin tocar el borde)
uniform vec2 franja = vec2(-1.0, -1.0);
uniform vec3 arena = vec3(0.747, 0.573, 0.499);   // medida en la imagen
uniform float luz_sombra = 0.27;                  // luz media de la sombra

void fragment() {
	vec4 c = COLOR;
	if (franja.x < 0.0 && UV.y < hasta_uv) {
		c.a = smoothstep(desde_a, hasta_a, c.a);
	}
	float zona = 1.0 - smoothstep(sin_sombra_uv * 0.8, sin_sombra_uv, UV.y);
	if (franja.x >= 0.0) {
		float b = (franja.y - franja.x) * 0.15;
		zona = smoothstep(franja.x, franja.x + b, UV.y) * (1.0 - smoothstep(franja.y - b, franja.y, UV.y));
	}
	// (lo azul se mide en la textura emborronada, mip 3,5: con el pixel de cada
	// sitio, el filo de cada sombra se quedaba a medias y dejaba rayas finas que
	// vibraban al mover la camara)
	vec4 b = textureLod(TEXTURE, UV, 3.5);
	float azul = smoothstep(-0.02, 0.12, b.b - b.r);
	float l = dot(b.rgb, vec3(0.299, 0.587, 0.114));
	vec3 limpia = arena * mix(1.0, clamp(l / luz_sombra, 0.85, 1.1), 0.5);
	c.rgb = mix(c.rgb, limpia, azul * zona);
	COLOR = c;
}
