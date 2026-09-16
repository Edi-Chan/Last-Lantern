shader_type canvas_item;
render_mode unshaded;

uniform float wind_speed = 1.35;
uniform float wind_pixels = 1.6;

void vertex() {
	float phase = INSTANCE_CUSTOM.r + VERTEX.x * 0.04;
	float strength = max(INSTANCE_CUSTOM.g, 0.12);
	float height = 1.0 - UV.y;
	float wave = sin(TIME * wind_speed + phase) * wind_pixels * height * height * strength;
	VERTEX.x += wave;
}
