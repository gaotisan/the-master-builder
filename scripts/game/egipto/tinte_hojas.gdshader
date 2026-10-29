shader_type canvas_item;
// Las hojas que vuelan del portal (hojas_portal.gd): como las posadas
// (hojas_lecho.gdshader, viraje), menos amarillas, hacia ocre y oliva.
uniform float desatura = 0.0;
uniform vec3 tinte = vec3(1.0);

void fragment() {
	vec4 c = COLOR;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(l), desatura) * tinte;
	COLOR = c;
}
