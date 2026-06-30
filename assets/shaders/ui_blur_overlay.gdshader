shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float blur_scale : hint_range(0.0, 4.0) = 1.6;
uniform vec4 tint_color : source_color = vec4(0.02, 0.03, 0.06, 0.72);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE * blur_scale;
	vec3 sample_color = vec3(0.0);
	sample_color += texture(screen_texture, uv).rgb;
	sample_color += texture(screen_texture, uv + vec2(px.x, 0.0)).rgb;
	sample_color += texture(screen_texture, uv - vec2(px.x, 0.0)).rgb;
	sample_color += texture(screen_texture, uv + vec2(0.0, px.y)).rgb;
	sample_color += texture(screen_texture, uv - vec2(0.0, px.y)).rgb;
	sample_color += texture(screen_texture, uv + px).rgb;
	sample_color += texture(screen_texture, uv - px).rgb;
	sample_color += texture(screen_texture, uv + vec2(px.x, -px.y)).rgb;
	sample_color += texture(screen_texture, uv + vec2(-px.x, px.y)).rgb;
	sample_color *= 0.111111;

	vec3 final_rgb = mix(sample_color, tint_color.rgb, tint_color.a);
	COLOR = vec4(final_rgb, 1.0);
}
