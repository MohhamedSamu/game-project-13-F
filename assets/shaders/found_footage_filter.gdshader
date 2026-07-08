shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform float intensity : hint_range(0.0, 1.0) = 0.48;
uniform float grain_amount : hint_range(0.0, 1.0) = 0.12;
uniform float grain_size : hint_range(0.5, 8.0) = 2.4;
uniform float grain_drift : hint_range(0.0, 1.0) = 0.0;
uniform float chromatic_aberration : hint_range(0.0, 0.02) = 0.0022;
uniform float barrel_distortion : hint_range(0.0, 0.6) = 0.05;
uniform float vignette : hint_range(0.0, 1.0) = 0.28;
uniform float vignette_aspect : hint_range(0.85, 1.25) = 1.06;
uniform float vignette_edge_softness : hint_range(0.08, 0.55) = 0.28;
uniform float scanlines : hint_range(0.0, 1.0) = 0.025;
uniform float saturation : hint_range(0.0, 1.5) = 0.62;
uniform float contrast : hint_range(0.5, 1.5) = 0.98;
uniform float lift : hint_range(0.0, 0.15) = 0.028;
uniform float shadow_crush : hint_range(0.0, 1.0) = 0.22;
uniform float cool_tint : hint_range(0.0, 0.3) = 0.08;
uniform float shadow_coolth : hint_range(0.0, 0.3) = 0.1;
uniform float softness : hint_range(0.0, 3.0) = 0.3;
uniform float bloom : hint_range(0.0, 1.0) = 0.09;

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 barrel_distort(vec2 uv, float amount) {
	vec2 cc = uv - 0.5;
	float dist2 = dot(cc, cc);
	return uv + cc * dist2 * amount;
}

float film_grain(vec2 uv, float drift) {
	vec2 p = floor(uv * vec2(1280.0, 720.0) / grain_size);
	float t = drift > 0.001 ? floor(TIME * drift * 0.1) : 0.0;
	float coarse = hash12(p + vec2(t, t * 0.37));
	float fine = hash12(p + vec2(17.3, 9.1));
	return (coarse * 0.55 + fine * 0.45) * 2.0 - 1.0;
}

vec3 desaturate(vec3 color, float amount) {
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	return mix(vec3(luma), color, amount);
}

vec3 sample_soft(vec2 uv, float amount) {
	vec2 texel = 1.0 / vec2(textureSize(screen_texture, 0));
	vec3 col = texture(screen_texture, uv).rgb;
	col += texture(screen_texture, uv + vec2(texel.x, 0.0) * amount).rgb;
	col += texture(screen_texture, uv - vec2(texel.x, 0.0) * amount).rgb;
	col += texture(screen_texture, uv + vec2(0.0, texel.y) * amount).rgb;
	col += texture(screen_texture, uv - vec2(0.0, texel.y) * amount).rgb;
	return col / 5.0;
}

vec3 sample_chromatic(vec2 uv, float aberration, float dist) {
	float ab = aberration * dist * dist;
	vec2 dir = normalize((uv - 0.5) + vec2(0.0001));
	float r = texture(screen_texture, uv + dir * ab).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv - dir * ab * 1.15).b;
	return vec3(r, g, b);
}

vec3 color_grade(vec3 color) {
	color = color * contrast + vec3(lift);
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	float crushed = smoothstep(0.0, shadow_crush, luma);
	color = mix(vec3(lift * 0.4), color, crushed);
	color = desaturate(color, saturation);

	float lo = 1.0 - smoothstep(0.0, 0.5, luma);
	float mid = smoothstep(0.15, 0.75, luma) * (1.0 - smoothstep(0.75, 1.0, luma));

	color.b += cool_tint * (0.25 + mid * 0.2);
	color.g += cool_tint * 0.06;
	color.r -= cool_tint * 0.16;
	color.b += shadow_coolth * lo * 1.1;
	color.g += shadow_coolth * lo * 0.1;
	color.r -= shadow_coolth * lo * 0.12;
	return color;
}

vec3 apply_bloom(vec2 uv, vec3 base, float amount) {
	vec2 texel = 1.0 / vec2(textureSize(screen_texture, 0));
	vec3 blur = vec3(0.0);
	blur += texture(screen_texture, uv + texel * vec2(2.5, 0.0)).rgb;
	blur += texture(screen_texture, uv - texel * vec2(2.5, 0.0)).rgb;
	blur += texture(screen_texture, uv + texel * vec2(0.0, 2.5)).rgb;
	blur += texture(screen_texture, uv - texel * vec2(0.0, 2.5)).rgb;
	blur *= 0.25;
	float bright = max(max(blur.r, blur.g), blur.b);
	float mask = smoothstep(0.5, 0.92, bright);
	return base + blur * mask * amount;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 distorted_uv = clamp(barrel_distort(uv, barrel_distortion), vec2(0.001), vec2(0.999));
	vec2 center = distorted_uv - 0.5;
	float dist = length(center);

	vec3 original = texture(screen_texture, uv).rgb;

	vec3 color = sample_soft(distorted_uv, softness);
	vec3 chroma = sample_chromatic(distorted_uv, chromatic_aberration, dist);
	color = mix(color, chroma, 0.75);

	color = color_grade(color);
	color = apply_bloom(distorted_uv, color, bloom);

	float scan = sin(distorted_uv.y * 720.0 * 3.14159265) * 0.5 + 0.5;
	color *= mix(1.0, scan, scanlines);

	color += film_grain(distorted_uv, grain_drift) * grain_amount;

	float vig_x = center.x * vignette_aspect;
	float vig_y = center.y / mix(1.0, vignette_aspect, 0.35);
	float vig_dist = length(vec2(vig_x, vig_y));
	float vig = smoothstep(0.92, 0.12 + vignette_edge_softness, vig_dist);
	color *= mix(1.0 - vignette, 1.0, vig);

	COLOR = vec4(mix(original, color, intensity), 1.0);
}
