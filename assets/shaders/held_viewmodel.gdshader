shader_type spatial;
render_mode blend_mix, cull_disabled, depth_test_disabled;

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform float albedo_alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 sample = texture(albedo_texture, UV);
	ALBEDO = sample.rgb;
	ALPHA = sample.a * albedo_alpha;
}
