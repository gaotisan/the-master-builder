shader_type canvas_item;
// Los adornos del recorrido que se mecen con el aire (egipto_acto1.gd,
// _montar_adornos): lo apoyado se mece por arriba (el pie quieto) y lo que
// cuelga, por abajo (el canto quieto). Se tuerce el cuadro del sprite: cada uno
// con su fase (por donde esta), dos senos para que no parezca un metronomo.
uniform float amplitud = 8.0;     // px (de la textura) en lo que se mueve
uniform bool cuelga = false;

void vertex() {
	float fase = MODEL_MATRIX[3].x * 0.004;
	float w = cuelga ? UV.y : 1.0 - UV.y;
	float s = sin(TIME * 1.1 + fase) * 0.65 + sin(TIME * 2.3 + fase * 1.7) * 0.35;
	VERTEX.x += s * amplitud * w;
}
