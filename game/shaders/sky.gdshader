shader_type sky;
// Gradient sky with sun/moon disc and glow, drifting fbm clouds that are lit
// from the sun side, and a hazy horizon. Driven by SkyController uniforms.

uniform vec3 top_color : source_color = vec3(0.22, 0.48, 0.9);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.86, 0.98);
uniform vec3 ground_color : source_color = vec3(0.4, 0.5, 0.6);
uniform vec3 sun_dir = vec3(0.0, 0.7, 0.7);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform float sun_energy = 1.0;     // 0 hides the disc/glow
uniform float disc_size = 0.022;    // radians-ish
uniform float cloud_cover = 0.5;    // 0..1
uniform float cloud_dark = 0.0;     // 0 white, 1 storm grey
uniform vec3 cloud_tint : source_color = vec3(1.0);
uniform float cloud_time = 0.0;
uniform float cloud_quality = 1.0;  // 0 = flat gradient only (low graphics)

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

float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += vnoise(p) * a;
		p = p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return s;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = dir.y;
	vec3 col;
	if (h >= 0.0) {
		col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.45));
	} else {
		col = mix(horizon_color, ground_color, clamp(-h * 5.0, 0.0, 1.0));
	}
	float sd = max(dot(dir, normalize(sun_dir)), 0.0);
	// soft glow round the sun/moon
	col += sun_color * (pow(sd, 6.0) * 0.12 + pow(sd, 60.0) * 0.35) * sun_energy;

	if (cloud_quality > 0.5 && h > 0.0) {
		vec2 uv = dir.xz / (h + 0.22) * 0.55 + vec2(cloud_time * 0.012, cloud_time * 0.005);
		float d = fbm(uv * 1.3);
		float thr = 1.0 - cloud_cover * 0.78;
		float c = smoothstep(thr, thr + 0.2, d);
		// thicker cloud is darker underneath and brighter on the sun side
		float dens = smoothstep(thr, thr + 0.5, d);
		vec3 lit = mix(vec3(1.0), vec3(0.55, 0.58, 0.64), cloud_dark);
		vec3 shade = mix(vec3(0.7, 0.75, 0.84), vec3(0.3, 0.32, 0.37), cloud_dark);
		vec3 ccol = mix(lit, shade, dens * 0.8) * cloud_tint;
		ccol += sun_color * pow(sd, 5.0) * 0.4 * (1.0 - dens) * sun_energy * (1.0 - cloud_dark);
		float horizon_fade = smoothstep(0.0, 0.16, h);
		col = mix(col, ccol, c * horizon_fade);
	}
	// bright disc on top
	float disc = smoothstep(disc_size, disc_size * 0.8, acos(clamp(sd, -1.0, 1.0))) * sun_energy;
	col = mix(col, sun_color * 1.6, disc * (1.0 - 0.7 * cloud_dark));
	COLOR = col;
}
