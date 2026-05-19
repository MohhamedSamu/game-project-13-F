shader_type sky;

uniform vec3 sky_day_color : source_color;
uniform vec3 sky_night_color : source_color;
uniform vec3 sky_sunset_color : source_color;
uniform float day_factor = 0.0;
uniform float sunset_factor = 0.0;
uniform float night_factor = 0.0;
uniform float star_factor = 0.0;
// Cuántas "celdas" en el cielo (cantidad). NO controla el tamaño en pantalla.
uniform float star_density = 140.0;
uniform float star_brightness = 1.15;
// Radio del punto en espacio UV del cielo (0.004–0.03). Independiente de star_density.
uniform float star_size = 0.014;
uniform float star_glow = 1.6;
uniform float star_horizon_cutoff = 0.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 dir_to_sky_uv(vec3 dir) {
	return vec2(atan(dir.z, dir.x) / TAU + 0.5, asin(clamp(dir.y, -1.0, 1.0)) / PI + 0.5);
}

// Tamaño del punto NO encoge al subir star_density (antes pasaba lo contrario).
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
	float d = length(local - jitter * 0.55);
	float size = radius_uv * mix(0.7, 1.35, hash21(cell + 93.2));
	float bright = 0.45 + 0.55 * hash21(cell + 201.5);
	return smoothstep(size, 0.0, d) * bright;
}

float starfield(vec3 dir) {
	float s = 0.0;
	s += star_layer(dir, vec2(2.0, 1.0), 0.86, star_size);
	s += star_layer(dir, vec2(1.0, 0.55), 0.91, star_size * 1.45);
	s += star_layer(dir, vec2(4.2, 2.1), 0.955, star_size * 0.75);
	return clamp(s, 0.0, 2.5);
}

void sky() {
	vec3 dir = normalize(EYEDIR);

	vec3 base = mix(sky_night_color, sky_day_color, day_factor);
	base = mix(base, sky_sunset_color, sunset_factor * 0.55);

	float h = clamp(dir.y * 0.5 + 0.5, 0.0, 1.0);
	float horizon_mask = mix(1.0, smoothstep(0.08, 0.35, h), star_horizon_cutoff);

	float stars_raw = starfield(dir);
	float twinkle = 0.88 + 0.12 * sin(TIME * 1.1 + hash21(dir.xz * 40.0) * 6.28318);
	vec3 stars = vec3(stars_raw * twinkle * star_brightness * star_glow) * star_factor * horizon_mask;

	COLOR = base + stars;
}
