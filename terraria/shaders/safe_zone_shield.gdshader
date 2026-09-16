shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float radius_px = 704.0;
uniform vec2 rect_size = vec2(1648.0, 1648.0);
uniform float pulse = 1.0;
uniform float intensity = 1.0;
uniform float level_power = 0.0;
uniform float time_scroll = 0.0;
uniform float lightning_boost = 0.0;
uniform float underground_fade = 1.0;
uniform float debug_ring = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 local = (UV - vec2(0.5)) * rect_size;
	float dist = length(local);
	float ang = atan(local.y, local.x);
	float n = vnoise(vec2(ang * 2.15, time_scroll * 0.12));
	float n2 = vnoise(vec2(ang * 5.4 + time_scroll * 0.38, dist * 0.018));
	float radius = radius_px + (n - 0.5) * (4.5 + level_power * 7.0);
	float ad = abs(dist - radius);
	float inside = 1.0 - smoothstep(radius - 14.0, radius + 3.0, dist);

	if (ad > 128.0 && inside < 0.002) {
		discard;
	}

	float core = exp(-ad * ad / 18.0);
	float inner = exp(-ad * ad / 140.0);
	float mid = exp(-ad * ad / 820.0);
	float outer = exp(-ad * ad / 2600.0);
	float scatter = exp(-ad * ad / 6200.0);
	float halo2 = exp(-((dist - (radius + 11.0 + level_power * 10.0)) * (dist - (radius + 11.0 + level_power * 10.0))) / 520.0);
	halo2 *= level_power;

	float veins = pow(max(sin(ang * (6.0 + level_power * 5.0) + time_scroll * 0.52 + n2 * 3.4), 0.0), 9.0);
	veins *= smoothstep(26.0, 5.0, ad) * (0.18 + level_power * 0.9);

	float sparks = step(0.975, hash(vec2(floor(ang * 28.0), floor(time_scroll * 0.7))));
	sparks *= smoothstep(14.0, 2.0, ad) * (0.12 + level_power * 0.45);

	vec3 core_col = mix(vec3(1.0, 0.95, 0.78), vec3(1.0, 0.98, 0.92), level_power);
	vec3 gold = vec3(1.0, 0.80, 0.34);
	vec3 amber = vec3(1.0, 0.52, 0.16);

	vec3 rgb = core_col * core * (1.25 + lightning_boost * 0.28);
	rgb += gold * inner * 0.92;
	rgb += gold * mid * 0.48;
	rgb += amber * outer * 0.32;
	rgb += amber * scatter * 0.14;
	rgb += core_col * halo2 * 0.55;
	rgb += core_col * veins * 0.72;
	rgb += core_col * sparks * 0.85;
	rgb += vec3(1.0, 0.84, 0.48) * inside * (0.028 + level_power * 0.022) * intensity;

	float under = smoothstep(4.0, 70.0, local.y);
	float vis = mix(1.0, 0.05, under * underground_fade);
	float energy = pulse * intensity * vis;

	if (debug_ring > 0.5 && abs(dist - radius_px) < 1.5) {
		rgb = vec3(0.15, 1.0, 0.28);
		energy = 1.0;
	}

	COLOR = vec4(rgb * energy, 1.0);
}
