shader_type spatial;
render_mode blend_mix, cull_front, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
// Tank glass + water tint. Clear through the middle, with a bright fresnel rim at grazing
// angles so the edges read as glass. cull_front because the box is viewed from outside and we
// want to see the fish through the near pane.

uniform vec4 water_color : source_color = vec4(0.20, 0.55, 0.70, 0.14);
uniform vec3 rim_color : source_color = vec3(0.65, 0.92, 1.0);
uniform float rim_power = 2.6;
uniform float rim_strength = 0.7;

void fragment() {
	float fres = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), rim_power);
	ALBEDO = water_color.rgb + rim_color * fres * rim_strength;
	ALPHA = clamp(water_color.a + fres * rim_strength, 0.0, 1.0);
	ROUGHNESS = 0.04;
	METALLIC = 0.12;
}
