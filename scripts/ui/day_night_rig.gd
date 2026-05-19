extends Node3D

@export var cycle_seconds: float = 40.0
@export var tilt_degrees: float = 20.0

# Órbita visual (distancia desde el pivote). Ponle el valor que ya te evitó atravesar el mapa.
@export var orbit_radius: float = 2800.0

# Energía de luces
@export var sun_energy_day: float = 2.0
@export var moon_energy_night: float = 0.35

# Transición día/noche alrededor del horizonte
@export_range(0.0, 0.5, 0.01) var transition_softness: float = 0.15

# Exposición (tonemap exposure) controlada por script
@export var exposure_day: float = 1.0
@export var exposure_night: float = 0.75

# Colores del cielo (uniforms del sky shader)
@export var sky_day_color: Color = Color(0.55, 0.75, 1.0, 1.0)      # celeste claro
@export var sky_sunset_color: Color = Color(1.0, 0.45, 0.15, 1.0)   # anaranjado/rojizo
@export var sky_night_color: Color = Color(0.03, 0.04, 0.08, 1.0)   # noche (azul muy oscuro)

# Estrellas — los valores del inspector del rig mandan cada frame (el .tres solo es vista previa).
@export_range(40.0, 400.0, 1.0) var star_density: float = 140.0
@export_range(0.2, 3.0, 0.05) var star_brightness: float = 1.15
@export_range(0.004, 0.035, 0.001) var star_size: float = 0.014
@export_range(0.5, 3.0, 0.1) var star_glow: float = 1.6
## 0 = estrellas en toda la esfera del cielo; 1 = solo sobre el horizonte (útil en FPS)
@export_range(0.0, 1.0, 0.01) var star_horizon_cutoff: float = 0.0
## Hora del ciclo en t=0 (amanecer). t=0.5 ≈ atardecer (18:00 con sunrise=6).
@export_range(0.0, 23.0, 0.25) var cycle_sunrise_hour: float = 6.0
@export_range(0.0, 23.0, 0.25) var star_start_hour: float = 18.5
@export_range(0.0, 23.0, 0.25) var star_end_hour: float = 5.5
@export_range(0.0, 3.0, 0.1) var star_fade_hours: float = 1.0
## No mostrar estrellas si el cielo aún tiene tono atardecer / no está lo bastante oscuro
@export_range(0.0, 1.0, 0.01) var star_max_sunset_factor: float = 0.12
@export_range(0.0, 1.0, 0.01) var star_min_night_factor: float = 0.58

# Qué tan ancho es el “atardecer” alrededor del horizonte
@export_range(0.0, 0.5, 0.01) var sunset_band: float = 0.18

# Debug (opcional)
@export var debug_print: bool = false

@onready var sun_pivot: Node3D = $SunPivot
@onready var moon_pivot: Node3D = $MoonPivot

@onready var sun_light: DirectionalLight3D = $SunPivot/SunDirectional
@onready var moon_light: DirectionalLight3D = $MoonPivot/MoonDirectional

@onready var sun_sprite: Sprite3D = $SunPivot/SunSprite3D
@onready var moon_sprite: Sprite3D = $MoonPivot/MoonSprite3D

@onready var we: WorldEnvironment = $WorldEnvironment

var t: float = 0.0 # 0..1
var _sky_material: ShaderMaterial

func _ready() -> void:
	rotation_degrees.z = tilt_degrees

	sun_sprite.position = Vector3(0.0, 0.0, -orbit_radius)
	moon_sprite.position = Vector3(0.0, 0.0, -orbit_radius)

	_cache_sky_material()

	if we.environment:
		we.environment.background_mode = Environment.BG_SKY

	if debug_print:
		print("WE path:", we.get_path())
		print("Sky material:", _sky_material)

func _process(delta: float) -> void:
	if cycle_seconds <= 0.01:
		return

	t = fposmod(t + delta / cycle_seconds, 1.0)
	var ang: float = t * TAU

	var sun_height: float = sin(ang)

	sun_pivot.rotation.x = ang
	moon_pivot.rotation.x = ang + PI

	_align_directional_light(sun_sprite, sun_pivot, sun_light)
	_align_directional_light(moon_sprite, moon_pivot, moon_light)

	var day_factor: float = _smooth_horizon(sun_height, transition_softness)
	var night_factor: float = 1.0 - day_factor

	sun_light.light_energy = lerp(0.0, sun_energy_day, day_factor)
	moon_light.light_energy = lerp(0.0, moon_energy_night, night_factor)

	sun_light.shadow_enabled = day_factor > 0.35
	moon_light.shadow_enabled = night_factor > 0.35

	if we.environment:
		we.environment.tonemap_exposure = lerp(exposure_night, exposure_day, day_factor)

	var sunset_factor: float = _sunset_factor(sun_height, sunset_band)
	var star_factor: float = _star_visibility_factor(sunset_factor, night_factor)
	_update_sky_shader(day_factor, sunset_factor, night_factor, star_factor)

	if debug_print and Engine.get_frames_drawn() % 60 == 0:
		print(
			"hour:", _cycle_hour(),
			" stars:", star_factor,
			" sunset:", sunset_factor,
			" night:", night_factor
		)

func _cache_sky_material() -> void:
	_sky_material = null
	if we == null or we.environment == null or we.environment.sky == null:
		return
	var mat: Material = we.environment.sky.sky_material
	if mat is ShaderMaterial:
		_sky_material = mat as ShaderMaterial

func _update_sky_shader(
	day_factor: float,
	sunset_factor: float,
	night_factor: float,
	star_factor: float
) -> void:
	if _sky_material == null:
		return

	_sky_material.set_shader_parameter("sky_day_color", sky_day_color)
	_sky_material.set_shader_parameter("sky_night_color", sky_night_color)
	_sky_material.set_shader_parameter("sky_sunset_color", sky_sunset_color)
	_sky_material.set_shader_parameter("day_factor", day_factor)
	_sky_material.set_shader_parameter("sunset_factor", sunset_factor)
	_sky_material.set_shader_parameter("night_factor", night_factor)
	_sky_material.set_shader_parameter("star_factor", star_factor)
	_sky_material.set_shader_parameter("star_density", star_density)
	_sky_material.set_shader_parameter("star_brightness", star_brightness)
	_sky_material.set_shader_parameter("star_size", star_size)
	_sky_material.set_shader_parameter("star_glow", star_glow)
	_sky_material.set_shader_parameter("star_horizon_cutoff", star_horizon_cutoff)

func _cycle_hour() -> float:
	return fposmod(cycle_sunrise_hour + t * 24.0, 24.0)

func _star_hour_factor() -> float:
	var hour := _cycle_hour()
	var fade := maxf(star_fade_hours, 0.001)
	var start_h := star_start_hour
	var end_h := star_end_hour

	if start_h > end_h:
		if hour >= start_h:
			return 1.0
		if hour >= start_h - fade:
			return smoothstep(start_h - fade, start_h, hour)
		if hour < end_h:
			return 1.0
		if hour < end_h + fade:
			return 1.0 - smoothstep(end_h, end_h + fade, hour)
		return 0.0

	if hour < start_h - fade or hour >= end_h + fade:
		return 0.0
	if hour < start_h:
		return smoothstep(start_h - fade, start_h, hour)
	if hour < end_h:
		return 1.0
	return 1.0 - smoothstep(end_h, end_h + fade, hour)

func _star_visibility_factor(sunset_factor: float, night_factor: float) -> float:
	var by_hour := _star_hour_factor()
	var dark_enough := smoothstep(
		star_min_night_factor - 0.12,
		star_min_night_factor + 0.08,
		night_factor
	)
	var no_sunset := 1.0 - smoothstep(
		star_max_sunset_factor,
		star_max_sunset_factor + 0.18,
		sunset_factor
	)
	return by_hour * dark_enough * no_sunset

func _align_directional_light(sprite: Sprite3D, pivot: Node3D, light: DirectionalLight3D) -> void:
	var dir := pivot.global_position - sprite.global_position
	if dir.length_squared() < 0.0001:
		return
	var forward := dir.normalized()
	var up := Vector3.UP
	if absf(forward.dot(up)) > 0.99:
		up = Vector3.RIGHT
	light.global_basis = Basis.looking_at(forward, up)

func _smooth_horizon(h: float, softness: float) -> float:
	var x: float = clamp((h * 0.5) + 0.5, 0.0, 1.0)
	var a: float = clamp(0.5 - softness, 0.0, 1.0)
	var b: float = clamp(0.5 + softness, 0.0, 1.0)
	return smoothstep(a, b, x)

func _sunset_factor(h: float, band: float) -> float:
	var d: float = abs(h)
	var denom: float = max(0.001, band)
	var x: float = 1.0 - clamp(d / denom, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)
