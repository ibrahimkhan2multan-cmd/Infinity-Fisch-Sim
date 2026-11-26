shader_type spatial;
// Stylised shader for every baked prop, building, character, rod and fish.
//  * COLOR.rgb  = albedo (sRGB, as authored)
//  * COLOR.a    = 1 - wind sway weight (1 = rigid, 0 = leaves in the wind)
//  * world-space value noise gently breaks up flat colours
//  * a soft fresnel rim lifts silhouettes so models read against the terrain

uniform float roughness_v : hint_range(0.0, 1.0) = 0.82;
uniform float specular_v : hint_range(0.0, 1.0) = 0.25;
uniform float sway_strength = 1.0;
uniform float noise_amount = 0.10;
uniform float rim_amount = 0.10;

varying vec3 wpos;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), f.x),
			mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	float w = 1.0 - COLOR.a;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (w > 0.01) {
		float ph = TIME * 1.5 + wp.x * 0.31 + wp.z * 0.23;
		float amp = w * sway_strength * (0.05 + 0.025 * max(VERTEX.y, 0.0));
		VERTEX.x += sin(ph) * amp;
		VERTEX.z += cos(ph * 0.83 + 1.3) * amp * 0.7;
	}
	wpos = wp;
}

void fragment() {
	vec3 col = pow(COLOR.rgb, vec3(2.2));
	float n = vnoise(wpos.xz * 1.7 + wpos.y * 0.9);
	col *= 1.0 - noise_amount * 0.5 + noise_amount * n;
	ALBEDO = col;
	ROUGHNESS = roughness_v;
	SPECULAR = specular_v;
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	EMISSION = col * f * rim_amount;
}
