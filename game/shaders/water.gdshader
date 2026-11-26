shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert, specular_schlick_ggx;
// Water: depth-tinted (from a baked terrain height texture, so shallows go
// turquoise and the seabed shows through), animated analytic wave normals,
// sun glints, fresnel sky reflection and animated shoreline foam.

uniform vec4 shallow_color : source_color = vec4(0.14, 0.58, 0.74, 0.82);
uniform vec4 deep_color : source_color = vec4(0.05, 0.28, 0.5, 0.9);
uniform float wave_amp = 0.6;
uniform float detail = 1.0;          // 0 = flat colour (low graphics), 1 = animated
uniform float edge_fade = 0.0;       // 1 = radial alpha fade (overlay discs)
uniform float tint_strength = 1.0;
uniform float night_dim = 1.0;       // 1 = day brightness, <1 = darker
uniform float depth_effects = 1.0;   // 0 for tinted overlay discs
uniform vec3 sky_color : source_color = vec3(0.6, 0.78, 0.95);
uniform sampler2D height_tex : filter_linear, repeat_disable;
uniform vec2 height_origin = vec2(-400.0, -400.0);
uniform float height_size = 800.0;
uniform float h_min = -8.0;
uniform float h_max = 4.0;

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

// gradient of one directional sine wave
vec2 wave(vec2 p, vec2 dir, float freq, float speed, float amp, float t) {
	return dir * cos(dot(p, dir) * freq + t * speed) * freq * amp;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float dist = length(VERTEX);
	vec2 p = wpos.xz;
	float t = TIME;

	// ---- wave normal -------------------------------------------------
	vec2 g = vec2(0.0);
	if (detail > 0.5) {
		g += wave(p, normalize(vec2(1.0, 0.35)), 0.30, 0.9, 0.55, t);
		g += wave(p, normalize(vec2(-0.4, 1.0)), 0.52, 1.3, 0.35, t);
		g += wave(p, normalize(vec2(0.7, -0.8)), 1.10, 1.9, 0.18, t);
		g += wave(p, normalize(vec2(-1.0, -0.2)), 2.30, 2.7, 0.08, t);
		// fine ripples that fade out in the distance (avoids shimmering)
		float fine = 1.0 - smoothstep(25.0, 140.0, dist);
		g += (vec2(vnoise(p * 1.9 + t * 0.35), vnoise(p * 1.9 - t * 0.3 + 7.0)) - 0.5) * 0.35 * fine;
		g *= wave_amp * 0.55 / (1.0 + dist * 0.004);
	}
	vec3 wn = normalize(vec3(-g.x, 1.0, -g.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);

	// ---- depth from the baked height map ------------------------------
	float depth = 12.0;
	if (depth_effects > 0.5) {
		vec2 huv = (p - height_origin) / height_size;
		float th = mix(h_min, h_max, texture(height_tex, huv).r);
		depth = max(wpos.y - th, 0.0);
	}
	float dmix = smoothstep(0.0, 11.0, depth);
	vec3 col = mix(shallow_color.rgb, deep_color.rgb, dmix);
	float a = mix(0.28, mix(deep_color.a, shallow_color.a, 1.0 - dmix), smoothstep(0.0, 1.6, depth));
	if (depth_effects < 0.5) {
		a = mix(deep_color.a, shallow_color.a, 0.5);
	}

	// tone variation + caustic-like shimmer in the shallows
	float n = vnoise(p * 0.18 + t * 0.05);
	col *= 0.92 + 0.16 * n;
	float caustic = pow(vnoise(p * 1.4 + vec2(t * 0.4, -t * 0.3)) * vnoise(p * 1.1 - vec2(t * 0.25, t * 0.35) + 4.0), 1.5);
	col += vec3(0.7, 0.95, 0.9) * caustic * (1.0 - dmix) * 0.5 * float(detail > 0.5);

	// ---- shoreline foam -----------------------------------------------
	float foam = 0.0;
	if (depth_effects > 0.5 && detail > 0.5) {
		float pulse = 0.28 * sin(t * 1.3 + depth * 4.0 + n * 6.0);
		float edge = 1.0 - smoothstep(0.02, 0.65, depth + pulse);
		float lace = smoothstep(0.30, 0.62, vnoise(p * 2.3 + vec2(t * 0.15, 0.0)) * 0.7 + vnoise(p * 5.7 - t * 0.1) * 0.5);
		foam = edge * (0.45 + 0.55 * lace);
		foam += (1.0 - smoothstep(0.0, 0.12, depth)) * 0.5;
		foam = clamp(foam, 0.0, 1.0);
	}

	// ---- fresnel sky reflection ---------------------------------------
	float fres = pow(1.0 - clamp(dot(NORMAL, normalize(VIEW)), 0.0, 1.0), 4.0);
	fres = clamp(fres * 0.9 + 0.03, 0.0, 1.0);

	vec3 water = col * night_dim;
	ALBEDO = mix(water, vec3(0.95, 0.98, 1.0) * night_dim, foam);
	EMISSION = sky_color * fres * 0.55 * (1.0 - foam);
	a = clamp(max(a + fres * 0.25, foam * 0.92), 0.0, 1.0);
	if (edge_fade > 0.5) {
		float d = length(UV - vec2(0.5)) * 2.0;
		a *= (1.0 - smoothstep(0.55, 1.0, d)) * tint_strength;
	}
	ALPHA = a;
	ROUGHNESS = mix(0.05, 0.9, foam);
	SPECULAR = 0.85;
}
