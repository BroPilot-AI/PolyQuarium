shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, depth_draw_never, shadows_disabled;
// Soft volumetric-looking light shafts. Applied to a few thin camera-facing quads in the upper
// tank: additive, brighter near the surface, fading to nothing at the floor, with a slow
// horizontal shimmer so the shafts breathe.

uniform vec3 ray_color : source_color = vec3(0.55, 0.82, 1.0);
uniform float top_y = 2.0;
uniform float bottom_y = 0.3;
uniform float strength = 0.16;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = clamp((wpos.y - bottom_y) / max(top_y - bottom_y, 0.001), 0.0, 1.0);
	float a = t * strength;
	a *= 0.65 + 0.35 * sin(wpos.x * 2.5 + TIME * 0.8);   // gentle breathing
	// Fade toward the quad's vertical edges so shafts don't look like hard slabs.
	a *= smoothstep(0.0, 0.35, UV.x) * smoothstep(1.0, 0.65, UV.x);
	ALBEDO = ray_color;
	ALPHA = max(a, 0.0);
}
