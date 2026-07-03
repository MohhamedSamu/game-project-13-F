shader_type spatial;
render_mode blend_mix, cull_disabled, depth_test_disabled;

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float albedo_alpha : hint_range(0.0, 1.0) = 1.0;
uniform bool use_albedo_texture = true;

void fragment() {
	if (use_albedo_texture) {
		vec4 tex_sample = texture(albedo_texture, UV);
		ALBEDO = tex_sample.rgb * albedo_color.rgb;
		ALPHA = tex_sample.a * albedo_color.a * albedo_alpha;
	} else {
		ALBEDO = albedo_color.rgb;
		ALPHA = albedo_color.a * albedo_alpha;
	}
}
