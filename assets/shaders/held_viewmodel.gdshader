shader_type spatial;
render_mode blend_mix, cull_disabled, depth_test_disabled, unshaded;

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float albedo_alpha : hint_range(0.0, 1.0) = 1.0;
uniform bool use_albedo_texture = true;
uniform float brightness : hint_range(0.0, 1.5) = 0.82;
uniform float saturation : hint_range(0.0, 1.5) = 0.88;

vec3 tonemap_viewmodel(vec3 rgb) {
	float luma = dot(rgb, vec3(0.299, 0.587, 0.114));
	rgb = mix(vec3(luma), rgb, saturation);
	return rgb * brightness;
}

void fragment() {
	if (use_albedo_texture) {
		vec4 tex_sample = texture(albedo_texture, UV);
		ALBEDO = tonemap_viewmodel(tex_sample.rgb * albedo_color.rgb);
		ALPHA = tex_sample.a * albedo_color.a * albedo_alpha;
	} else {
		ALBEDO = tonemap_viewmodel(albedo_color.rgb);
		ALPHA = albedo_color.a * albedo_alpha;
	}
}
