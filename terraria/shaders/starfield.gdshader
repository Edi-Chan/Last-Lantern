shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float visibility : hint_range(0.0, 1.0) = 0.0;
uniform float twinkle_time = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 grid = floor(SCREEN_UV * vec2(210.0, 118.0));
	float n = hash(grid);
	float star = step(0.987, n);
	float bright = mix(0.28, 1.0, hash(grid + 19.2));
	float tw = 0.62 + 0.38 * sin(twinkle_time * mix(1.1, 3.3, hash(grid + 3.1)) + hash(grid.yx) * 6.28318);
	float a = star * bright * tw * visibility;
	vec3 col = mix(vec3(0.78, 0.84, 1.0), vec3(1.0, 0.94, 0.82), hash(grid + 8.8));
	COLOR = vec4(col, a);
}
