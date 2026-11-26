shader_type spatial;
// Lamp glass and window panes: dull by day, glowing warm at night.
uniform float night = 0.0;          // 0 day .. 1 night (set by SkyController)
uniform float day_emission = 0.12;
uniform float night_emission = 2.2;
uniform float glassy = 0.0;         // 1 = window pane (sky-ish reflection by day)

void fragment() {
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	ALBEDO = c * mix(0.55, 0.15, night);
	float e = mix(day_emission, night_emission, night);
	vec3 warm = vec3(1.0, 0.72, 0.38);
	vec3 tint = mix(c, warm, night * glassy * 0.85);
	EMISSION = tint * e;
	ROUGHNESS = mix(0.5, 0.1, glassy);
	SPECULAR = 0.6;
}
