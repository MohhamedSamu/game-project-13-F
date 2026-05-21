// sky_day_night — cielo + estrellas (nubes volumétricas: Sunshine Clouds 2)
shader_type sky;

uniform vec3 sky_day_color : source_color;
uniform vec3 sky_night_color : source_color;
uniform vec3 sky_sunset_color : source_color;
uniform float day_factor = 0.0;
uniform float sunset_factor = 0.0;
uniform float night_factor = 0.0;
uniform float star_factor = 0.0;
uniform float star_density = 140.0;
uniform float star_brightness = 1.15;
uniform float star_size = 0.014;
uniform float star_glow = 1.6;
uniform float star_horizon_cutoff = 0.0;
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_direction = vec3(0.0, 1.0, 0.0);
uniform float sun_disc_strength = 0.0;
uniform float moon_disc_strength = 0.0;
uniform float sun_angular_size = 0.022;
uniform float moon_angular_size = 0.016;
uniform vec3 sun_disc_color : source_color = vec3(1.0, 0.92, 0.55);
uniform vec3 moon_disc_color : source_color = vec3(0.88, 0.92, 1.0);

const float TAU_F = 6.28318530718;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 dir_to_sky_uv(vec3 dir) {
	return vec2(atan(dir.z, dir.x) / TAU_F + 0.5, asin(clamp(dir.y, -1.0, 1.0)) / PI + 0.5);
}

float star_layer(vec3 dir, vec2 grid_mul, float spawn_chance, float radius_uv) {
	vec2 uv = dir_to_sky_uv(dir);
	vec2 p = uv * star_density * grid_mul;
	vec2 cell = floor(p);
	vec2 local = fract(p) - 0.5;
	float h = hash21(cell);
	if (h > spawn_chance) {
		return 0.0;
	}
	vec2 jitter = vec2(hash21(cell + 17.3), hash21(cell + 41.7)) - 0.5;
	float dist = length(local - jitter * 0.55);
	float size = radius_uv * mix(0.7, 1.35, hash21(cell + 93.2));
	float bright = 0.45 + 0.55 * hash21(cell + 201.5);
	return smoothstep(size, 0.0, dist) * bright;
}

float starfield(vec3 dir) {
	float s = 0.0;
	s += star_layer(dir, vec2(2.0, 1.0), 0.86, star_size);
	s += star_layer(dir, vec2(1.0, 0.55), 0.91, star_size * 1.45);
	s += star_layer(dir, vec2(4.2, 2.1), 0.955, star_size * 0.75);
	return clamp(s, 0.0, 2.5);
}

float celestial_disc(vec3 view_dir, vec3 body_dir, float angular_radius, float strength) {
	if (strength <= 0.0) {
		return 0.0;
	}
	float d = dot(normalize(view_dir), normalize(body_dir));
	float edge = cos(angular_radius);
	float core = cos(angular_radius * 0.55);
	return smoothstep(edge, core, d) * strength;
}

void sky() {
	vec3 dir = normalize(EYEDIR);

	vec3 base = mix(sky_night_color, sky_day_color, day_factor);
	base = mix(base, sky_night_color, night_factor * 0.92);
	base = mix(base, sky_sunset_color, sunset_factor * 0.55);

	float h = clamp(dir.y * 0.5 + 0.5, 0.0, 1.0);
	float horizon_mask = mix(1.0, smoothstep(0.08, 0.35, h), star_horizon_cutoff);
	float stars_raw = starfield(dir);
	float twinkle = 0.88 + 0.12 * sin(TIME * 1.1 + hash21(dir.xz * 40.0) * TAU_F);
	vec3 stars = vec3(stars_raw * twinkle * star_brightness * star_glow) * star_factor * horizon_mask;

	float sun_d = celestial_disc(dir, sun_direction, sun_angular_size, sun_disc_strength);
	float moon_d = celestial_disc(dir, moon_direction, moon_angular_size, moon_disc_strength);
	vec3 sun_glow = sun_disc_color * sun_d;
	vec3 moon_glow = moon_disc_color * moon_d;

	COLOR = base + stars + sun_glow + moon_glow;
}
