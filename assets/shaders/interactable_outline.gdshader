shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, blend_mix;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 0.82);
uniform float outline_width : hint_range(0.0, 0.08, 0.0005) = 0.012;

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
