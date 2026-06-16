shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, diffuse_burley;
// A subtle rippling surface plane at the top of the tank. Vertices bob on crossing sine waves
// and the tint shifts with them, so the waterline reads as moving water rather than a flat lid.

uniform vec4 surf_color : source_color = vec4(0.40, 0.70, 0.85, 0.22);
uniform float wave_height = 0.03;
uniform float wave_scale = 4.0;
uniform float wave_speed = 1.4;

varying float ripple;

void vertex() {
	float r = sin(VERTEX.x * wave_scale + TIME * wave_speed)
		+ cos(VERTEX.z * wave_scale - TIME * wave_speed * 0.8);
	VERTEX.y += r * wave_height;
	ripple = r * 0.5 + 0.5;
}

void fragment() {
	ALBEDO = surf_color.rgb + vec3(0.15) * ripple;
	ALPHA = clamp(surf_color.a + ripple * 0.12, 0.0, 1.0);
	ROUGHNESS = 0.08;
	METALLIC = 0.25;
}
