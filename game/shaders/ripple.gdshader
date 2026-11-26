shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
// Expanding rings under the bobber.
uniform float strength = 1.0;
uniform float speed = 0.8;
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float ph = fract(TIME * speed);
	float a = 0.0;
	for (int i = 0; i < 3; i++) {
		float r = fract(ph + float(i) / 3.0);
		a += smoothstep(0.06, 0.0, abs(d - r)) * (1.0 - r);
	}
	ALBEDO = vec3(1.0);
	ALPHA = clamp(a, 0.0, 1.0) * 0.55 * strength * (1.0 - smoothstep(0.9, 1.0, d));
}
