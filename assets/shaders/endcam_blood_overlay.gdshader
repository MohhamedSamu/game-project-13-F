shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float intensity : hint_range(0.0, 1.5) = 1.0;
uniform float drip_amount : hint_range(0.0, 1.0) = 0.85;
uniform float splat_amount : hint_range(0.0, 1.0) = 1.0;
uniform float edge_pool : hint_range(0.0, 1.0) = 0.72;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform vec3 blood_dark : source_color = vec3(0.18, 0.01, 0.01);
uniform vec3 blood_mid : source_color = vec3(0.42, 0.02, 0.015);
uniform vec3 blood_bright : source_color = vec3(0.72, 0.05, 0.03);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.05;
		a *= 0.5;
	}
	return v;
}

float splat_blob(vec2 uv, vec2 center, float radius, float stretch) {
	vec2 d = uv - center;
	d.y *= stretch;
	float dist = length(d);
	float soft = smoothstep(radius, radius * 0.35, dist);
	float edge = fbm(uv * 28.0 + center * 7.0);
	return soft * smoothstep(0.25, 0.72, edge + soft * 0.35);
}

float drip_streak(vec2 uv, float x, float top, float length_y, float width) {
	float dx = abs(uv.x - x);
	float along = (uv.y - top) / max(length_y, 0.001);
	float body = 1.0 - smoothstep(width, width * 2.4, dx);
	body *= smoothstep(0.0, 0.08, along) * (1.0 - smoothstep(0.75, 1.05, along));
	float wobble = fbm(vec2(x * 40.0, uv.y * 18.0));
	body *= smoothstep(0.2, 0.7, wobble + body * 0.4);
	float tip = 1.0 - smoothstep(0.02, 0.09, length(uv - vec2(x + (wobble - 0.5) * 0.01, top + length_y)));
	return max(body, tip * 0.85);
}

void fragment() {
	vec2 uv = UV;
	float aspect = max(SCREEN_PIXEL_SIZE.y / max(SCREEN_PIXEL_SIZE.x, 0.0001), 0.001);
	vec2 p = uv;
	p.x = (p.x - 0.5) * mix(1.0, 1.0 / aspect, 0.35) + 0.5;

	float mask = 0.0;

	// Edge pooling (blood on lens rim / corners)
	float edge_x = min(uv.x, 1.0 - uv.x);
	float edge_y = min(uv.y, 1.0 - uv.y);
	float rim = 1.0 - smoothstep(0.0, 0.22, min(edge_x, edge_y));
	rim = pow(rim, 1.35);
	float rim_noise = fbm(uv * 9.0 + vec2(2.1, 0.7));
	mask += rim * rim_noise * edge_pool * 1.35;

	// Corner blobs
	mask += splat_blob(p, vec2(0.08, 0.12), 0.22, 1.15) * splat_amount * 0.95;
	mask += splat_blob(p, vec2(0.92, 0.1), 0.2, 1.2) * splat_amount * 0.9;
	mask += splat_blob(p, vec2(0.12, 0.88), 0.24, 0.9) * splat_amount * 0.85;
	mask += splat_blob(p, vec2(0.9, 0.86), 0.21, 0.95) * splat_amount * 0.8;
	mask += splat_blob(p, vec2(0.28, 0.06), 0.14, 1.4) * splat_amount * 0.7;
	mask += splat_blob(p, vec2(0.72, 0.08), 0.13, 1.35) * splat_amount * 0.65;
	mask += splat_blob(p, vec2(0.55, 0.95), 0.18, 0.85) * splat_amount * 0.55;
	mask += splat_blob(p, vec2(0.05, 0.45), 0.12, 1.1) * splat_amount * 0.5;
	mask += splat_blob(p, vec2(0.96, 0.52), 0.11, 1.05) * splat_amount * 0.48;

	// Small mid splatters
	mask += splat_blob(p, vec2(0.38, 0.22), 0.05, 1.0) * splat_amount * 0.45;
	mask += splat_blob(p, vec2(0.62, 0.3), 0.04, 1.1) * splat_amount * 0.4;
	mask += splat_blob(p, vec2(0.48, 0.7), 0.045, 0.95) * splat_amount * 0.35;

	// Vertical drips
	mask += drip_streak(uv, 0.14, 0.05, 0.42, 0.012) * drip_amount;
	mask += drip_streak(uv, 0.27, 0.02, 0.55, 0.01) * drip_amount * 0.9;
	mask += drip_streak(uv, 0.71, 0.04, 0.48, 0.011) * drip_amount * 0.95;
	mask += drip_streak(uv, 0.86, 0.08, 0.38, 0.013) * drip_amount * 0.85;
	mask += drip_streak(uv, 0.52, 0.0, 0.28, 0.008) * drip_amount * 0.55;
	mask += drip_streak(uv, 0.41, 0.12, 0.22, 0.007) * drip_amount * 0.4;

	// Organic breakup so it doesn't look painted flat
	float organic = fbm(uv * 14.0 + vec2(0.3, 1.7));
	mask *= mix(0.55, 1.15, organic);
	mask = clamp(mask, 0.0, 1.4);

	float pulse_boost = 1.0 + pulse * 0.22;
	mask *= intensity * pulse_boost;

	float depth = clamp(mask, 0.0, 1.0);
	vec3 color = mix(blood_mid, blood_dark, smoothstep(0.25, 0.95, depth));
	color = mix(color, blood_bright, pow(1.0 - depth, 2.2) * 0.35 * step(0.08, depth));

	// Specular wet highlight on thicker blobs
	float wet = smoothstep(0.45, 0.9, depth) * (0.15 + 0.2 * noise(uv * 40.0));
	color += vec3(wet * 0.35, wet * 0.05, wet * 0.02);

	float alpha = smoothstep(0.04, 0.55, depth) * clamp(intensity, 0.0, 1.2);
	alpha = min(alpha, 0.92);

	COLOR = vec4(color, alpha);
}
