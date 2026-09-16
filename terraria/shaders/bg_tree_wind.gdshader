shader_type canvas_item;
render_mode unshaded;

uniform float wind_pixels = 1.7;
uniform float wind_speed = 0.52;

void vertex() {
	float height = 1.0 - UV.y;
	VERTEX.x += sin(TIME * wind_speed + VERTEX.x * 0.012) * wind_pixels * height * height;
}
