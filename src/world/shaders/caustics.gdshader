shader_type spatial;
render_mode cull_back, diffuse_burley;
// Animated underwater caustics for the tank floor: shifting ribbons of light, like sun
// refracting through a rippling surface. Cheap (a couple of trig layers), world-space so the
// pattern is continuous across the sand regardless of mesh UVs.

uniform vec3 base_color : source_color = vec3(0.85, 0.78, 0.6);
uniform vec3 caustic_tint : source_color = vec3(0.55, 0.78, 0.95);
uniform float caustic_scale = 3.5;
uniform float caustic_speed = 0.5;
uniform float caustic_strength = 0.7;
uniform float sharpness = 6.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Two layered, counter-scrolling sine fields multiplied together read as moving caustic cells.
float caustics(vec2 p) {
	float t = TIME * caustic_speed;
	vec2 a = p * caustic_scale;
	float v1 = sin(a.x + t) * cos(a.y - t * 0.9);
	float v2 = sin(a.x * 1.7 - t * 1.3) * cos(a.y * 1.4 + t * 0.6);
	float v = (v1 + v2) * 0.25 + 0.5;          // -> roughly 0..1
	return pow(clamp(v, 0.0, 1.0), sharpness);  // high power -> thin bright ribbons
}

void fragment() {
	float c = caustics(world_pos.xz);
	ALBEDO = base_color + caustic_tint * (c * caustic_strength);
	ROUGHNESS = 1.0;
}
