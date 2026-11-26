shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled, blend_add;

uniform float intensity = 0.0;
varying vec3 dir;

float hash13(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void vertex() {
	dir = normalize(VERTEX);
}

void fragment() {
	vec3 d = normalize(dir);
	vec3 g = d * 70.0;
	vec3 id = floor(g);
	float h = hash13(id);
	vec3 f = fract(g) - vec3(0.5);
	float star = step(0.975, h) * smoothstep(0.42, 0.0, length(f));
	float twinkle = 0.65 + 0.35 * sin(TIME * 2.0 + h * 60.0);
	float horizon = smoothstep(0.02, 0.25, d.y);
	ALBEDO = vec3(star * twinkle * horizon * intensity);
}
