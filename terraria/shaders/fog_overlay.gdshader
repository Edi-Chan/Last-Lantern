shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest, repeat_disable;

uniform float fog_density : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fog_color : source_color = vec4(0.012, 0.008, 0.020, 1.0);
uniform vec4 fog_color_b : source_color = vec4(0.090, 0.018, 0.140, 1.0);
uniform vec4 fog_color_c : source_color = vec4(0.120, 0.016, 0.028, 1.0);
uniform vec4 warm_color : source_color = vec4(1.0, 0.82, 0.48, 0.16);
uniform vec4 lightning_color : source_color = vec4(0.78, 0.42, 1.0, 1.0);
uniform vec2 camera_center = vec2(0.0);
uniform vec2 view_size = vec2(640.0, 360.0);
uniform vec2 camera_zoom = vec2(1.0);
uniform vec2 safe_center_0 = vec2(0.0);
uniform vec2 safe_center_1 = vec2(0.0);
uniform vec2 safe_center_2 = vec2(0.0);
uniform vec2 safe_center_3 = vec2(0.0);
uniform vec4 safe_radii = vec4(0.0);
uniform vec2 player_world = vec2(0.0);
uniform float lightning_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float time_scroll = 0.0;
uniform float debug_border = 0.0;

const float TILE = 16.0;
const float ZONE_B = 5.0 * TILE;
const float ZONE_C = 12.0 * TILE;
const float ZONE_D = 25.0 * TILE;

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

float signed_zone(vec2 world, vec2 center, float radius) {
	if (radius <= 0.001) {
		return 1.0e9;
	}
	return distance(world, center) - radius;
}

void fragment() {
	if (fog_density <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		vec2 zoom = max(camera_zoom, vec2(0.0001));
		vec2 world = camera_center + (SCREEN_UV - vec2(0.5)) * view_size / zoom;

		float sd = min(signed_zone(world, safe_center_0, safe_radii.x), signed_zone(world, safe_center_1, safe_radii.y));
		sd = min(sd, min(signed_zone(world, safe_center_2, safe_radii.z), signed_zone(world, safe_center_3, safe_radii.w)));

		float n1 = vnoise(world * 0.0032 + vec2(time_scroll * 0.045, time_scroll * 0.018));
		float n2 = vnoise(world * 0.0088 + vec2(-time_scroll * 0.11, time_scroll * 0.04));
		float n3 = vnoise(world * 0.021 + vec2(time_scroll * 0.19, -time_scroll * 0.07));
		float n4 = vnoise(world * 0.046 + vec2(-time_scroll * 0.06, time_scroll * 0.16));
		float fog_n = n1 * 0.42 + n2 * 0.28 + n3 * 0.20 + n4 * 0.10;

		float edge = 1.0 - smoothstep(0.0, 48.0, abs(sd));
		sd += (fog_n - 0.5) * 22.0 * edge;

		float inside = 1.0 - smoothstep(-6.0, 8.0, sd);
		float outside = 1.0 - inside;
		float dist_out = max(sd, 0.0);

		float vis_b = mix(0.58, 0.40, fog_n);
		float vis_c = mix(0.18, 0.09, fog_n);
		float vis_d = mix(0.045, 0.016, fog_n);
		float vis_e = mix(0.010, 0.0018, fog_n);
		float vis_out = mix(vis_b, vis_c, smoothstep(0.0, ZONE_B, dist_out));
		vis_out = mix(vis_out, vis_d, smoothstep(ZONE_B, ZONE_C, dist_out));
		vis_out = mix(vis_out, vis_e, smoothstep(ZONE_C, ZONE_D, dist_out));

		float leak = (1.0 - smoothstep(0.0, ZONE_B, dist_out)) * outside;
		vis_out = max(vis_out, leak * mix(0.42, 0.26, fog_n));
		vis_out *= mix(1.0, 0.72, edge * (0.25 + fog_n * 0.55));

		float pvis = (1.0 - smoothstep(10.0, 72.0, distance(world, player_world))) * 0.42;
		vis_out = max(vis_out, pvis * outside);

		float flash = lightning_intensity * outside;
		vis_out = mix(vis_out, min(vis_out + flash * 0.46, 0.62), flash);

		float vis_in = 0.965 + n4 * 0.02;
		float vis = mix(vis_out, vis_in, inside);
		float ring_keep = exp(-(sd * sd) / 52.0);
		vis = max(vis, ring_keep * 0.95);
		vis = mix(vis, 1.0, 1.0 - fog_density);
		vis = clamp(vis, 0.0, 1.0);

		vec3 scene = texture(screen_texture, SCREEN_UV).rgb;
		vec3 col_black = fog_color.rgb;
		vec3 col_purple = fog_color_b.rgb;
		vec3 col_crimson = fog_color_c.rgb;
		vec3 col_navy = vec3(0.018, 0.022, 0.070);
		vec3 col_grey = vec3(0.045, 0.038, 0.048);
		vec3 cold = mix(col_black, col_purple, smoothstep(0.22, 0.72, n1));
		cold = mix(cold, col_crimson, smoothstep(0.48, 0.92, n2) * 0.70);
		cold = mix(cold, col_navy, (1.0 - fog_n) * 0.32);
		cold = mix(cold, col_grey, n4 * 0.12);
		cold = mix(cold, lightning_color.rgb * 0.42, flash);
		cold = mix(cold, vec3(0.16, 0.10, 0.05), leak * 0.40);
		vec3 rgb = mix(cold, scene, vis);
		rgb = mix(rgb, scene * vec3(1.10, 1.03, 0.88) + warm_color.rgb * 0.07, inside * fog_density * 0.42);
		rgb += vec3(1.0, 0.86, 0.48) * ring_keep * fog_density * 0.28;

		if (debug_border > 0.5) {
			float ring = 1.0 - smoothstep(0.0, 1.6, abs(sd));
			rgb = mix(rgb, vec3(0.2, 1.0, 0.3), ring);
		}

		COLOR = vec4(rgb, 1.0);
	}
}
