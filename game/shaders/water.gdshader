shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.14, 0.58, 0.74, 0.82);
uniform vec4 deep_color : source_color = vec4(0.05, 0.28, 0.5, 0.9);
uniform float wave_amp = 0.6;
uniform float detail = 1.0;        // 0 = flat colour (low graphics), 1 = animated
uniform float edge_fade = 0.0;     // 1 = radial alpha fade (overlay discs)
uniform float tint_strength = 1.0;
uniform float night_dim = 1.0;     // 1 = day brightness, <1 = darker

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = 0.0;
	if (detail > 0.5) {
		float t = TIME;
		float w1 = sin(wpos.x * 0.35 + t * 1.1) + sin(wpos.z * 0.29 - t * 0.9);
		float w2 = sin((wpos.x + wpos.z) * 0.8 + t * 1.9) * 0.5;
		float w3 = sin(wpos.x * 1.7 - t * 2.4) * sin(wpos.z * 1.5 + t * 2.0) * 0.5;
		n = (w1 * 0.4 + w2 * 0.35 + w3 * 0.25);
	}
	float mixv = clamp(0.5 + 0.28 * n * wave_amp, 0.0, 1.0);
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, mixv);
	float sparkle = max(0.0, n - 0.75) * 0.5 * wave_amp;
	ALBEDO = (col + vec3(sparkle)) * night_dim;
	float a = mix(deep_color.a, shallow_color.a, mixv);
	if (edge_fade > 0.5) {
		float d = length(UV - vec2(0.5)) * 2.0;
		a *= (1.0 - smoothstep(0.55, 1.0, d)) * tint_strength;
	}
	ALPHA = a;
	ROUGHNESS = 0.12;
	SPECULAR = 0.75;
}
