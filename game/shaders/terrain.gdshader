shader_type spatial;
render_mode diffuse_burley;
// Ground shader. Vertex colour carries the biome (blended smoothly between
// vertices); the fragment adds grass variation, sand speckle, slope rock and
// wet sand at the waterline from cheap world-space noise, so the ground no
// longer looks like flat green triangles.

uniform float detail_far = 120.0;
uniform float quality = 1.0;   // 0 = cheap ground (low graphics): colour + large patches only

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
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	vec2 p = wpos.xz;
	float dist = length(VERTEX);
	float near = 1.0 - smoothstep(detail_far * 0.35, detail_far, dist);
	float n1 = vnoise(p * 0.07);
	float n2 = 0.5;
	float n3 = 0.0;
	float n4 = 0.0;
	if (quality > 0.5) {
		n2 = vnoise(p * 0.31 + 11.0);
		n3 = vnoise(p * 1.9 + 5.0) * near;
		n4 = vnoise(p * 6.5 + 2.0) * near;
	}

	float greenness = clamp((base.g - max(base.r, base.b) * 1.05) * 9.0, 0.0, 1.0);
	float sandness = clamp(1.0 - greenness, 0.0, 1.0);

	// meadow: large patches of lighter/yellower and deeper greens + blade speckle
	vec3 grass = base * mix(vec3(0.78, 0.92, 0.7), vec3(1.25, 1.12, 0.72), n1);
	grass *= 0.9 + 0.2 * n2;
	grass *= 0.95 + 0.1 * n3;
	grass += vec3(0.012, 0.03, 0.0) * smoothstep(0.55, 0.95, n4) * near;
	// sand / path: grain and slightly wavy tone
	vec3 sand = base * (0.9 + 0.18 * n2) * (0.93 + 0.14 * n3);
	vec3 col = mix(sand, grass, greenness);

	// slope -> rock
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float rockiness = smoothstep(0.88, 0.7, wn.y);
	vec3 rock = vec3(0.2, 0.19, 0.17) * (0.8 + 0.5 * n2) * (0.85 + 0.3 * n3);
	col = mix(col, rock, rockiness * 0.8);

	// wet sand near the waterline
	float wet = 1.0 - smoothstep(0.35, 1.1, wpos.y);
	col *= mix(1.0, 0.72, wet * sandness);
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.75, wet * sandness);
	SPECULAR = 0.15;
}
