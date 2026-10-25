shader_type canvas_item;
// EL VIENTO DE LAS PLANTAS DE EGIPTO: la textura se mece mas cuanto mas lejos
// de la base (o de lo alto, si cuelga: la hiedra). La fase sale de donde esta
// la planta en el mundo, asi que dos iguales no se mueven a la vez. Sin pasadas
// a pantalla completa: solo los pixeles de la planta.

uniform float amplitud = 0.012;     // en UV, en lo mas alejado del ancla
uniform float rapidez = 1.3;
uniform bool colgante = false;      // anclada arriba (hiedra)
uniform bool agua = false;          // el agua: brillos que corren, sin mecerse

varying float fase;

void vertex() {
	vec2 mundo = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	fase = mundo.x * 0.0037 + mundo.y * 0.001;
}

void fragment() {
	vec2 uv = UV;
	if (agua) {
		vec4 c = texture(TEXTURE, uv);
		float onda = sin(uv.x * 220.0 + TIME * 1.7 + fase) * sin(uv.x * 61.0 - TIME * 0.9);
		float brillo = smoothstep(0.75, 1.0, onda) * smoothstep(0.55, 0.0, uv.y);
		c.rgb += vec3(0.85, 0.9, 0.82) * brillo * 0.35;
		COLOR = c * COLOR;
	} else {
		float lejos = colgante ? uv.y : 1.0 - uv.y;
		float k = lejos * lejos;
		float t = TIME * rapidez + fase;
		// racha lenta + temblor
		float s = sin(t) * 0.7 + sin(t * 2.3 + 1.7) * 0.3;
		uv.x += s * amplitud * k;
		vec4 c = texture(TEXTURE, uv);
		COLOR = c * COLOR;
	}
}
